#!/usr/bin/env python

"""
written by: chase mateusiak 20220126
The expectation that a barcode of length n has been added by UMI tools to the
ID of each read. The script extracts that molecular barcode and adds it to
the alignment record with tag RG. For example, RG:ATCAGT might be added to
a given line.
"""
# standard library
import os
import sys
import argparse
# pysam must be in the PYTHONPATH
import pysam


def parse_args(args=None):
    Description = "Add the tags which UMI added to the read ID \
        as a Read Group (RG) tag to each alignment record."
    Epilog = "Example usage: python add_read_group_to_bam.py \
        <sorted_indexed_in.bam> <read_group_tagged_out.bam>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("bam", help="Input bam, already sorted and indexed")
    parser.add_argument("read_group_tagged_out", help="Output file.")
    parser.add_argument("id_length", help="length of the barcode.")
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


def add_read_group(bam, read_group_tagged_bam_out, id_length):
    """
    :param file_in: path to the sorted, indexed bam file with UMI IDs in the ID entry
    :param file_out: the same bam, but with the UMI ID added as a RG: tag
    :param id_length: length of the UMI ID

    Look at each read, extract the ID, add it as a tag (tag prefix RG) and write out
    to another bam. Output is the same bam, but with RG:<index> added to each line

    """

    barcode_set = set()

    # Check that input bampath exists
    if not os.path.exists(bam):
        print_error(
            "Input bam does not exists: {}".format(bam),
            "File",bam,
    )

    # sort and index
    sorted_bam = bam.replace(".bam", "_sorted.bam")
    pysam.sort("-o", sorted_bam, "-@","10", bam)
    pysam.index(sorted_bam)

    # open the input bam
    samfile = pysam.AlignmentFile(sorted_bam, "rb")

    # get copy of the header
    new_header = samfile.header.copy().to_dict()
    # loop through the reads in the input bam, extract unique barcodes
    # TODO parallelize this
    for read in samfile.fetch():
        # extract the ID from the ID line
        read_dict = read.to_dict()
        barcode = read_dict['name'][-id_length:]
        barcode_set.add(barcode)

    # create new read group header and add to the new_header obj
    new_header['RG'] = [{'ID': barcode} for barcode in barcode_set]

    samfile.close()

    samfile = pysam.AlignmentFile(sorted_bam, "rb")
    # open a file to which to write
    tagged_bam = pysam.AlignmentFile(read_group_tagged_bam_out, "wb", header = new_header)
    for read in samfile.fetch():
        # extract the ID from the ID line
        read_dict = read.to_dict()
        barcode = read_dict['name'][-id_length:]
        # add the read group tag to the line
        read.set_tag("RG", barcode)
        # write to file
        tagged_bam.write(read)

    tagged_bam.close()
    samfile.close()

    # index the output
    pysam.index(read_group_tagged_bam_out)

def main(args=None):
    args = parse_args(args)
    add_read_group(args.bam,
                   args.read_group_tagged_out,
                   int(args.id_length))


if __name__ == "__main__":
    sys.exit(main())
