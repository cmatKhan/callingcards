//
// Run samtools mpileup with the following option
// QNAME,FLAG,POS,MAPQ,RNEXT,PNEXT,RG where RG is the read group tag
//

include { SAMTOOLS_MPILEUP } from '../../modules/nf-core/modules/samtools/mpileup/main'

workflow PILEUP_BY_GROUP {
    take:
    bam            // channel: [ val(meta), [ bam ], [bai] ]
    genome          // channel: file(ref_genome)

    main:

    ch_versions = Channel.empty()

    //
    // index the genome with bwamem2 index
    //
    SAMTOOLS_MPILEUP ( bam, genome )
    ch_versions = ch_versions.mix(SAMTOOLS_MPILEUP.out.versions)

    emit:
    mpileup        = SAMTOOLS_MPILEUP.out.mpileup     // channel: [ val(meta), [ mpileup ] ]
    versions       = ch_versions                    // channel: [ versions.yml ]
}
