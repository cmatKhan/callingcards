//
// Run samtools mpileup with the following option
// QNAME,FLAG,POS,MAPQ,RNEXT,PNEXT,RG where RG is the read group tag
//

include { SAMTOOLS_MPILEUP } from '../../modules/nf-core/modules/samtools/mpileup/main'
include { CREATE_PILEUP_DB } from '../../modules/local/create_pileup_db'
include { CALCULATE_ENRICHMENT } from '../../modules/local/calculate_enrichment'

workflow PILEUP {
    take:
    bam            // channel: [ val(meta), [ bam ] ]
    genome          // channel: file(ref_genome)
    // other things here for the db and enrichment

    main:

    ch_versions = Channel.empty()

    //
    // index the genome with bwamem2 index
    //
    SAMTOOLS_MPILEUP ( bam, genome )
    ch_versions = ch_versions.mix(SAMTOOLS_MPILEUP.out.versions)

    //
    // create the pileup db
    //
    CREATE_PILEUP_DB ( SAMTOOLS_MPILEUP.out )
    ch_versions = ch_versions.mix(CREATE_PILEUP_DB.out.versions)

    //
    // Calculate enrichment over promoter regions
    //
    CALCULATE_ENRICHMENT( CREATE_PILEUP_DB.out )
    ch_versions = ch_versions.mix(CALCULATE_ENRICHMENT.out.versions)

    emit:
    mpileup        = SAMTOOLS_MPILEUP.out           // channel: [ val(meta), [ mpileup ] ]
    versions       = ch_versions                    // channel: [ versions.yml ]
}
