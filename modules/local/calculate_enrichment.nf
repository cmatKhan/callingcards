process SAMPLESHEET_CHECK {

    tag "$meta.id"
    label 'process_medium'

    container "path/to/container"

    input:
    tuple val(meta), path(pileup)
    path  fasta

    output:
    path '*.csv'       , emit: csv
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-core/callingcards/bin/
    """
    check_samplesheet.py \\
        $samplesheet \\
        samplesheet.valid.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
