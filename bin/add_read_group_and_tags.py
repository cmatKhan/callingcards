#!/usr/bin/env python

# TODO: better docstring
"""
written by: chase mateusiak 20220126

The expectation is that a barcode of length n has been added by UMI tools to the
ID of each read. This script extracts the unique set of IDs, adds them as @RG
tags in the header, adds the RG tag to each line, and adds the tags XI and XZ
to each read, where XI is the insertion coordinates and XZ is the insertion
sequence.
"""
# standard library
import os
import sys
import argparse
# outside dependencies
import pysam


def parse_args(args=None):
    Description = "Extract the barcode, added by UMItools, from each read id, \
                   Add the Read Group (RG) header, and add the appropriate \
                   RG tag to each alignment record, and add the XI and XZ tags \
                   which describe the insertion location and sequence at that \
                   location"
    Epilog = "Example usage: python add_read_group_and_tags.py \
        <input.bam> <output.bam> <genome.fasta> <genome.fasta.fai> \
        <id_length> <optional: insertion_length> <optional: nthreads>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("bampath_in",
                         help="path to the input bam file")
    parser.add_argument("bampath_out",
                         help="path to the output bam file")
    parser.add_argument("genome_path",
                         help = "Path to the .fasta genome used in the \
                                 alignment")
    parser.add_argument("genome_index_path",
                         help = "path to the .fai produced by samtools \
                                 faidx from the genome .fasta")
    parser.add_argument("id_length",
                        help="length of the barcode in the bam ID line")
    parser.add_argument("insertion_length",
                        help = "The length of the transposase insertion. \
                                Default is 1 since pysam uses 0 based half \
                                    open intervals. [0,1) returns 1 base",
                        default = '0')
    parser.add_argument("nthreads",
                        help="number of threads",
                        default = '1')

    return parser.parse_args(args)


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check the input to \
        add_read_group_to_bam.py -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check that the input bam \
            exists, is sorted, and is indexed -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)


def add_read_group_and_tags(bampath_in, bampath_out, genome_path,
                   genome_index_path, id_length, insertion_length, nthreads):
    """
    :param bampath_in: path to the sorted, indexed bam file with UMI IDs
                       in the ID entry
    :param bampath_out: the same bam, but with the UMI ID added as a RG: tag
    :param genome_path:
    :param genome_index_path:
    :param id_length: length of the barcode which is appended, after an _,
                      to the read id
    :param nthreads: number of threads to run in parallel during index/sort

    Look at each read, extract the ID, add it as a tag (tag prefix RG) and
    write out to another bam. Output is the same bam, but with RG:<index>
    added to each line
    """

    # TODO: Right now, this loops over the file twice to create the header,
    #       and then to add the tags to each read. Need to figure out how to
    #       add the header without re-writing the whole bam so that only loops
    #       one time.

    # open the genome file for random access on disc
    genome = pysam.FastaFile(genome_path, genome_index_path)

    # Prepare the input bam ----------------------------------------------------
    pysam.sort("-o", bampath_in, "-@", nthreads , bampath_in)
    pysam.index(bampath_in)

    # Get the set of unique barcodes in the input_bamfile ----------------------
    # extract current header
    new_header = input_bamfile.header.copy().to_dict()
    # instantiate a set object
    barcode_set = set()
    # open the input bam
    input_bamfile = pysam.AlignmentFile(bampath_in, "rb")
    # loop through the reads in the input bam, extract unique barcodes, add to
    # barcode set
    for read in input_bamfile.fetch():
        # extract the ID from the ID line
        read_dict = read.to_dict()
        barcode = read_dict['name'][-id_length:]
        barcode_set.add(barcode)
    # Create new read group header. Note: this is used below in the tagged_bam
    new_header['RG'] = [{'ID': barcode} for barcode in barcode_set]

    # Add RG, XI and XZ tags to each line in the bam file ----------------------
    input_bamfile = pysam.AlignmentFile(bampath_in, "rb")
    # open a file to which to write. Note: the new header
    tagged_bam = pysam.AlignmentFile(bampath_out, "wb", header = new_header)
    for read in input_bamfile.fetch():

        # Extract the length of any soft clipping ------------------------------
        # A cigartuple looks like [(0,4), (2,2), (1,6),..,(4,68)] if read
        # is reverse complement. If it is forward, it would have the (4,68),
        # in this case, in the first position.
        # The first entry in the tuple is the cigar operation and the
        # second is the length. Note that pysam does order the tuples in the
        # reverse order from the sam cigar specs, so cigar 30M would be
        # (0,30). 4 is cigar S or BAM_CSOFT_CLIP. The list operation below
        # extracts the length of cigar operation 4 and returns a integer.
        # if 4 DNE, then soft_clip_length is 0.
        soft_clip_length = sum([length for cigar_operation, length in
                                read.cigartuples if cigar_operation == 4 ])

        # Extract XI and XZ tags -----------------------------------------------
        # the flag is cast to an int and then a bitwise operation is performed
        # if the result is not zero, then the read is reverse complement.
        region_dict = dict()
        if read.flag & 0x10:
            # The insertion point is at the end of the alignment
            insert = read.reference_end
            # adjust insert for soft clipping
            insert = insert + soft_clip_length
            # The span of the n bases preceding the insertion are:
            # [insert, insert + n)
            region_dict['start'] = insert
            region_dict['end']   = insert + (insertion_length)
        # else, Read is in the forward orientation
        else:
            #
            insert = read.reference_start
            # adjust insert for soft clipping
            insert = insert - soft_clip_length
            # The span of the n bases preceding the insertions are:
            # [insert - n, insert)
            region_dict['start'] = insert - (insertion_length)
            region_dict['end']   = insert

        # Create the tag strings -----------------------------------------------
        tag_dict = dict()
        tag_dict['RG'] = read.query_name[-id_length:]
        tag_dict['XI'] = "{0}|{1}|{2}|+".format(read.reference_name,
                                        region_dict['start'],
                                        region_dict['end'])
        tag_dict['XZ'] = genome.fetch(read.reference_name,
                              region_dict['start'],
                              region_dict['end']).upper()

        # Set tags -------------------------------------------------------------
        # the list comprehension outputs [None, None, None, ...]. Out catches
        # this so it isn't printed to std out
        # how else to do this?
        out = [read.set_tag(tag,tag_str) for tag, tag_str in tag_dict.items()]
        # Write to file --------------------------------------------------------
        tagged_bam.write(read)

    # Close files --------------------------------------------------------------
    genome.close()
    tagged_bam.close()
    input_bamfile.close()

    # Re-index the output ------------------------------------------------------
    # TODO check if this is necessary...it is here only to prevent the message:
    # WARNING: bam timestamp and read timestamp are different that you sometimes
    # get when the bam is modified after the index is created
    pysam.index(bampath_out)

def main(args=None):
    args = parse_args(args)

    # Check inputs
    input_path_list = [args.bampath_in,
                       args.genome_path,
                       args.genome_index_path]
    # todo: throw fileDNE error, catch and sys.exit there, else
    # add_read_group_and_tags
    for input_path in input_path_list:
        if not os.path.exists(input_path):
            sys.exit("ADD_READ_GROUP_AND_TAGS_ERROR: Input file \
                      does not exists: {}".format(input_path))

    add_read_group_and_tags(args.bampath_in,
                            args.bampath_out,
                            args.genome_path,
                            args.genome_index_path,
                            int(args.id_length),
                            int(args.insertion_length),
                            args.nthreads)


if __name__ == "__main__":
    sys.exit(main())
