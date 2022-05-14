#!/usr/bin/env Rscript

library(callingCardsTools)

main = function(args){

create_cc_database(args$pileup_path,
                   args$barcode_length,
                   args$background_data_path,
                   args$db_output_path)

} # end main()

parseArguments <- function() {
  # parse and return cmd line input

  option_list <- list(
    make_option(c('-p', '--pileup_path'),
                help='path to the samtools mpileup output'),
    make_option(c('-b', '--barcode_length'),
                help='length of the barcode which maps reads to TFs'),
    make_option(c('-o', '--db_output_path'),
                help='path/name of the output sqlite database file'),
    make_option(c('-d', '--background_data_path'),
                help='path to the background data which will be used to calculate enrichment'))

  args <- parse_args(OptionParser(option_list=option_list))
  return(args)
} # end parseAarguments

main(parseArguments()) # call main method

# for testing -- dos omething like this, but with the appropriate arguments
# input_list = list()
# input_list['deseq_data_set'] = '/home/chase/code/cmatkhan/misc_scripts/deseq_model/data/test_2_counts.csv'
# input_list['output_directory'] = '/home/chase/Desktop/tmp/test_results'
# input_list['name'] = 'deseq_output_test'
# input_list['threads'] = '10'

# main(input_list)#!/usr/bin/env Rscript

