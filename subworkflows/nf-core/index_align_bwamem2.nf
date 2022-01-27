//
// Index the reference genome and align reads
//

include { BWAMEM2_INDEX } from '../../modules/nf-core/modules/bwamem2/index/main'
include { BWAMEM2_MEM } from '../../modules/nf-core/modules/bwamem2/mem/main'
include { BAM_SORT_SAMTOOLS } from '../nf-core/bam_sort_samtools'

workflow INDEX_ALIGN {
    take:
    reads            // channel: [ val(meta), [ reads ] ]
    reference_genome // channel: file(ref_genome)
    annotation_file

    main:

    ch_versions = Channel.empty()
    bwamem2_index = Channel.empty()

    //
    // index the genome with bwamem2 index
    //
    BWAMEM2_INDEX ( index ).index.set { bwamem2_index }
    ch_versions = ch_versions.mix(INDEX.out.versions.first())



    //
    // Map reads with bwamem2 mem
    //
    meta = reads[[0]]
    reads = reads[[1]]
    sort_bam = false
    BWAMEM2_MEM ( meta, reads, bwamem2_index, sort_bam )
    ch_versions = ch_versions.mix(STAR_ALIGN.out.versions.first())

    //
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    //
    BAM_SORT_SAMTOOLS ( BWAMEM2_MEM.out.bam )
    ch_versions = ch_versions.mix(BAM_SORT_SAMTOOLS.out.versions)

    emit:
    orig_bam       = STAR_ALIGN.out.bam             // channel: [ val(meta), bam            ]
    log_final      = STAR_ALIGN.out.log_final       // channel: [ val(meta), log_final      ]
    log_out        = STAR_ALIGN.out.log_out         // channel: [ val(meta), log_out        ]
    log_progress   = STAR_ALIGN.out.log_progress    // channel: [ val(meta), log_progress   ]
    bam_sorted     = STAR_ALIGN.out.bam_sorted      // channel: [ val(meta), bam_sorted     ]
    bam_transcript = STAR_ALIGN.out.bam_transcript  // channel: [ val(meta), bam_transcript ]
    fastq          = STAR_ALIGN.out.fastq           // channel: [ val(meta), fastq          ]
    tab            = STAR_ALIGN.out.tab             // channel: [ val(meta), tab            ]

    bam            = BAM_SORT_SAMTOOLS.out.bam      // channel: [ val(meta), [ bam ] ]
    bai            = BAM_SORT_SAMTOOLS.out.bai      // channel: [ val(meta), [ bai ] ]
    csi            = BAM_SORT_SAMTOOLS.out.csi      // channel: [ val(meta), [ csi ] ]
    stats          = BAM_SORT_SAMTOOLS.out.stats    // channel: [ val(meta), [ stats ] ]
    flagstat       = BAM_SORT_SAMTOOLS.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats       = BAM_SORT_SAMTOOLS.out.idxstats // channel: [ val(meta), [ idxstats ] ]

    versions       = ch_versions                    // channel: [ versions.yml ]
}

}
