# PGS-calculations

## Description
Scripts that are used to calculate polygenic scores.

## Files

`sumChromosomeScores.sh`:
  Shell script for merging PGSs over chromomsomes


`sumChromosomeScores.R`: 
  Corresponding R script that performs the actual merging of PGSs over chromosomes
  
  
`calculatePolygenicScores.sh`:
  Overarching script that submits `calculatePolygenicScoresForChromosome.sh` for every GWAS, chromosome
  
  
`calculatePolygenicScoresForChromosome.sh`:
  Script that calculates PGSs for a particular GWAS and chromosome

## Usage

In order to use the scripts for calculating polygenic scores, a couple of important parameters
have to be specified in `calculatePolygenicScores.sh` and `sumChromosomeScores.sh`.

- `RUN_IDENTIFIER`: An identifier of choice.
- `BFILE_PATH`: The location where processed genetic data is located in the PLINK 2.0 bpgen format.
The entire prefix of the bpgen files are formatted as follows `${BFILE_PATH}/${CHROM}.UGLI.imputed.qc.plink`
- `OUTDIR` / `OUTPUT`: Output directories for the respective scripts.
- `SUMMARY_DIR`: Base path of summary statistics
- `GWASES`: File that contains the summary statistics name corresponding to a GWAS in the first column, 
and the sample size for that GWAS in the second column (comma-separated).
- `LOGS`: Log file directory
- `LD_REFERENCE_PANEL`: LD reference panel to be used with PRScs.