//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channel(it "${projectDir}/assets/dummy_file.txt") }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
// where meta contains the sample id and path to the barcodes file
def create_fastq_channel(LinkedHashMap row, String dummy_file) {
    def meta = [:]
    def fastq_2 = row.fastq_2 == '' :
                    dummy_file ?
                    row.fastq_2

    meta.id           = row.sample
    // necessary in some of the nf-co modules. For calling cards,
    // the reads will always be paired end
    meta.single_end   = false

    if(!file(row.barcodes).exists()){
        exit 1, "ERROR: Please check input samplesheet -> the barcodes file does not exist!\n${row.barcodes}"

    }

    meta.barcodes     = row.barcodes

    def array = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    } else {
        if (!file(fastq_2).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${fastq_2}"
        }
        array = [ meta, [ file(row.fastq_1), file(fastq_2) ] ]
    }
    return array
}
