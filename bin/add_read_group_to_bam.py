#!/usr/bin/env python

import pysam

barcode_length = 5

bampath = "/home/oguzkhan/Desktop/tmp/cc_tester/results/bwamem2/test1_T1_sorted.bam"
outpath = "/home/oguzkhan/Desktop/tmp/cc_tester/results/bwamem2/test1_T1_sorted_tagged.bam"

samfile = pysam.AlignmentFile(bampath, "rb")
tagged_bam = pysam.AlignmentFile(outpath, "wb", template=samfile)

for read in samfile.fetch():
    read_dict = read.to_dict()
    barcode = read_dict['name'][-barcode_length:]
    read.set_tag("RG", barcode)
    tagged_bam.write(read)

tagged_bam.close()
samfile.close()
