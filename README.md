# ![nf-core/callingcards](docs/images/nf-core-callingcards_logo_light.png#gh-light-mode-only) ![nf-core/callingcards](docs/images/nf-core-callingcards_logo_dark.png#gh-dark-mode-only)

[![GitHub Actions CI Status](https://github.com/nf-core/callingcards/workflows/nf-core%20CI/badge.svg)](https://github.com/nf-core/callingcards/actions?query=workflow%3A%22nf-core+CI%22)
[![GitHub Actions Linting Status](https://github.com/nf-core/callingcards/workflows/nf-core%20linting/badge.svg)](https://github.com/nf-core/callingcards/actions?query=workflow%3A%22nf-core+linting%22)
[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/callingcards/results)
[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.10.3-23aa62.svg?labelColor=000000)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23callingcards-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/callingcards)
[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)
[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## DEVELOPMENT NOTES

### TL;DR

If you'd like to try this out on your own, you may copy this directory into
your own working directory:

```
/lts/mblab/personal/chasem/cc_tester
```

You might do this with `rsync` on the cluster like so:

```
rsync -aHv /lts/mblab/personal/chasem/cc_tester /scratch/<your_lab>/<your_scratch>/
```

Or you might pull this onto your local computer. As long as you have installed
Singularity and Nextflow (both easy -- search for the respective documentation
and follow the instructions. Don't bother with any 'how to' sites, just go do the docs).

On the new cluster, if you haven't already installed singularity and nextflow, do this:

```
$ interactive
$ spack install singularityce
$ spack install nextflow
```
Note that singularity is `singularityce`. At this point, you should be able
to follow the HTCF documentation to run this pipeline. If not, then the HTCF
documentation is lacking -- let me know, I'll help, and then we'll e-mail the
sys admins together with suggestions for better documentation.

To pull onto your local computer, do this:

```
scp -r <your_username>@login.htcf.wustl.edu:/lts/mblab/personal/cc_tester /path/on/your/computer/
```

It only takes 36 minutes or so to run this on a local.

Regardless of where you put the data, once it is there, `cd` into the directory.

__CRITICAL__ Before doing anything else, open the params.json file and change
the paths so that they accurately point to the files on your computer (it is a
near term to do to make this such that you could use relative paths, but for
now, you need absolute).

To launch the pipeline, now do this:

```
nextflow run nf-core-callingcards/main.nf -c local.config -params-file params.json -resume
```
Note that you may do this via an sbatch script.

The output will be in your `$PWD`, and will look like this:

```
> ls results
bwamem2  create  fastqc  multiqc  pipeline_info  promoter  samtools  umitools

```
The promoter enrichment is in `promoter`. The pileup database is in `create`.
The alignment file (bam) and raw pileup is in `samtools`. Fixing this output so
that things end up in mroe logical places is a near term `TODO`.
### A longer explanation

All basic steps of the pipeline currently run:

The barcodes are first extracted, and the reads trimmed, by UMItools. The reads
are sent through fastQC and then aligned. The alignment is indexed, sorted
and then transformed into a pileup. The pileup is processed into a sqlite database,
and that is used to extract reads over pre-defined promoter regions and to calculate
enrichment. The nice thing about parsing the pileup into a sqlite database is that
it is quick and easy to re-calculate enrichment with a different promoter definition.
see [calling cards tools](https://github.com/cmatKhan/callingCardsTools)

This will process any number of calling cards experiments simultaneously (or as
simultaneously as the cluster scheduler will allow). Also, a single calling cards
experiment can be processed on a local computer in about a half an hour.

The command to submit the job looks like this:

```
nextflow run nf-core-callingcards/main.nf -c local.config -params-file params.json -resume
```

params file looks like

```
{
  "input":"input_samplesheet.csv",
  "fasta":"\/home\/oguzkhan\/ref\/S288C_R64\/GCF_000146045.2_R64_genomic.fa",
  "r1_bc_pattern":"NNNNNXXXXXXXXXXXXXXXXX",
  "r2_bc_pattern":"NNNNNNNNXXXX",
  "barcode_length": 21,
  "samtools_mpileup_adjust_mq": 50,
  "min_mapq": 10,
  "promoter_bed": "\/home\/oguzkhan\/Desktop\/tmp\/cc_tester\/promoter_test.bed",
  "background_data": "\/home\/oguzkhan\/Desktop\/tmp\/cc_tester\/NOTF_Minus_Adh1_2015_17_combined_chase_edit.csv",
  "pileup_stranded": "FALSE"
}

```
input file looks like

__NOTE__: There is a caveat here. Currently, the path to the tf barcode map
must be the absolute path.
```
sample,fastq_1,fastq_2,barcodes
test1,PhiX_S1_R1_001.fastq.gz,PhiX_S1_R2_001.fastq.gz,demult_barcodes.tsv
```
where barcodes.tsv looks like

__MAKE SURE__ the tsv is actually a tsv. It is a good idea to read it into
R/python and parse it with read_tsv to make sure it comes out in two rows.
Checking this at input is a TODO that I haven't yet incorporated.
```
> cat demult_barcodes.tsv
MIG2    TCAGTCCCGTTGG
CAT8    GCCTGGGCGGCAG
GLN3    ATTTGGGGGGGGT
ARO80   TTGGTGGGGGTAG
CBF1    CTCGGTCGTCAGT
```
and the config looks like

```
> cat local.config
singularity {

  enabled = true
  autoMounts = true
  cacheDir = "${launchDir}/singularity_images/"
  runOptions = "--bind ${launchDir}/tmp:/tmp"

}

process {

  executor = "local"
  scratch = true
  scratch = "${launchDir}/tmp"

  withLabel:process_medium {
    cpus = { check_max( 6 * task.attempt, 'cpus' ) }
    memory = { check_max( 25.GB * task.attempt, 'memory' ) }
    time = { check_max( 8.h * task.attempt, 'time' ) }
  }

  withLabel:process_high {
    cpus = { check_max( 12 * task.attempt, 'cpus' ) }
    memory = { check_max( 25.GB * task.attempt, 'memory' ) }
    time = { check_max( 8.h * task.attempt, 'time' ) }
  }
}

params {

    // Max resource options
    // Defaults only, expecting to be overwritten
    max_memory                 = '128.GB'
    max_cpus                   = 24
    max_time                   = '240.h'

}

// Function to ensure that resource requirements don't go beyond
// a maximum limit
def check_max(obj, type) {
  if (type == 'memory') {
    try {
      if (obj.compareTo(params.max_memory as nextflow.util.MemoryUnit) == 1)
        return params.max_memory as nextflow.util.MemoryUnit
      else
        return obj
    } catch (all) {
      println "   ### ERROR ###   Max memory '${params.max_memory}' is not valid! Using default value: $obj"
      return obj
    }
  } else if (type == 'time') {
    try {
      if (obj.compareTo(params.max_time as nextflow.util.Duration) == 1)
        return params.max_time as nextflow.util.Duration
      else
        return obj
    } catch (all) {
      println "   ### ERROR ###   Max time '${params.max_time}' is not valid! Using default value: $obj"
      return obj
    }
  } else if (type == 'cpus') {
    try {
      return Math.min( obj, params.max_cpus as int )
    } catch (all) {
      println "   ### ERROR ###   Max cpus '${params.max_cpus}' is not valid! Using default value: $obj"
      return obj
    }
  }
}
```

## Introduction

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->
**nf-core/callingcards** is a bioinformatics analysis pipeline for processing Transposon Calling Cards sequencing data.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->
On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources. The results obtained from the full-sized test can be viewed on the [nf-core website](https://nf-co.re/callingcards/results).

## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->

1. Check the sample sheet
2. Append barcodes to the fastq ID line with UMI Tools ([`UMI Tools`](https://umi-tools.readthedocs.io/en/latest/))
2. Read QC ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
3. Align ([`bwamem2 mem`](https://github.com/bwa-mem2/bwa-mem2https://umi-tools.readthedocs.io/en/latest/))
4. Add the barcodes as read groups to the bam, index and sort. Implemented in ([a custom script](https://github.com/BrentLab/callingcards/blob/main/bin/add_read_group.py) using [pysam](https://pysam.readthedocs.io/en/latest/api.html).
5. Bam QC ([`Qualimap`](http://qualimap.conesalab.org/))
6.
5. Present QC for raw reads ([`MultiQC`](http://multiqc.info/))

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(please only use [`Conda`](https://conda.io/miniconda.html) as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_

3. Download the pipeline and test it on a minimal dataset with a single command:

    ```console
    nextflow run nf-core/callingcards -profile test,YOURPROFILE
    ```

    Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

    > * The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
    > * Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
    > * If you are using `singularity` and are persistently observing issues downloading Singularity images directly due to timeout or network issues, then you can use the `--singularity_pull_docker_container` parameter to pull and convert the Docker image instead. Alternatively, you can use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
    > * If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

    <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

    ```console
    nextflow run nf-core/callingcards -profile <docker/singularity/podman/shifter/charliecloud/conda/institute> --input samplesheet.csv --genome GRCh37
    ```

## Documentation

The nf-core/callingcards pipeline comes with documentation about the pipeline [usage](https://nf-co.re/callingcards/usage), [parameters](https://nf-co.re/callingcards/parameters) and [output](https://nf-co.re/callingcards/output).

## Credits

nf-core/callingcards was originally written by Chase Mateusiak, Woo Jung.

We thank the following people for their extensive assistance in the development of this pipeline:

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#callingcards` channel](https://nfcore.slack.com/channels/callingcards) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  nf-core/callingcards for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->
An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
