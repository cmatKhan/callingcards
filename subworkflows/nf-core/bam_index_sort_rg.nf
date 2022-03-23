//
// Sort, index BAM file and run samtools stats, flagstat and idxstats
// modified version of similar script in nf-co/rnaseq
//

include { ADD_READ_GROUP } from "../../modules/local/add_read_group"
include { BAM_STATS_SAMTOOLS } from './bam_stats_samtools'

workflow BAM_INDEX_SORT_RG {
    take:
    ch_bam // channel: [ val(meta), [ bam ] ]

    main:

    ch_versions = Channel.empty()

    // this also indexes and sorts the bam
    ADD_READ_GROUP ( ch_bam )
    ch_versions = ch_versions.mix(ADD_READ_GROUP.out.versions.first())

    // ADD_READ_GROUP.out.bam
    //     .map {
    //         meta, bam, bai, csi ->
    //             if (bai) {
    //                 [ meta, bam, bai ]
    //             } else {
    //                 [ meta, bam, csi ]
    //             }
    //     }
    //     .set { ch_bam_bai }

    BAM_STATS_SAMTOOLS ( ADD_READ_GROUP.out.bam ) //( ch_bam_bai )
    ch_versions = ch_versions.mix(BAM_STATS_SAMTOOLS.out.versions)

    emit:
    bam      = ADD_READ_GROUP.out.bam          // channel: [ val(meta), [ bam ], [bai/csi] ]
    stats    = BAM_STATS_SAMTOOLS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat = BAM_STATS_SAMTOOLS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats = BAM_STATS_SAMTOOLS.out.idxstats // channel: [ val(meta), [ idxstats ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}
