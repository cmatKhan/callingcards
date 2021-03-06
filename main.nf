#!/usr/bin/env nextflow
/*
========================================================================================
    nf-core/callingcards
========================================================================================
    Github : https://github.com/nf-core/callingcards
    Website: https://nf-co.re/callingcards
    Slack  : https://nfcore.slack.com/channels/callingcards
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    GENOME PARAMETER VALUES
========================================================================================
*/

params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { CALLINGCARDS } from './workflows/callingcards'

//
// WORKFLOW: Run main nf-core/callingcards analysis pipeline
//
workflow NFCORE_CALLINGCARDS {
    CALLINGCARDS ()
}

/*
========================================================================================
    RUN ALL WORKFLOWS
========================================================================================
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_CALLINGCARDS ()
}

/*
========================================================================================
    THE END
========================================================================================
*/
