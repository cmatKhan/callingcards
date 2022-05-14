#!/usr/bin/env Rscript

library(callingCardsTools)

main = function(args){

quant_df = calculateEnrichmentByHops(args$pileup_db,
                                     args$promoter_bedfile_path,
                                     args$barcode_tf_map_path,
                                     stranded = FALSE)

write.csv(enrichment_df, paste0(args$out_name, ".csv"))

} # end main()

parseArguments <- function() {
  # parse and return cmd line input

  option_list <- list(
    make_option(c('-p', '--pileup_db'),
                help='path to the pileup sqlite database file'),
    make_option(c('-b', '--promoter_bedfile_path'),
                help='a bed file of regions of interest'),
    make_option(c('-m', '--barcode_tf_map_path'),
                help='path to a tsv which maps TFs to barcodes'))

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

