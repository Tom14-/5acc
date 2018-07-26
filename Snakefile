#!/usr/bin/env python3

import os


#############
# FUNCTIONS #
#############

def FindAllFastqFiles(read_dir):
    '''Return a list of paths to fastq_files in read_dir'''
    read_dir_files = [(dirpath, filenames) for (dirpath, dirnames, filenames)
                      in os.walk(read_dir, followlinks=True)]
    fastq_files = []
    for dirpath, filenames in read_dir_files:
        for filename in filenames:
            if 'fastq.gz' in filename:
                fastq_files.append(os.path.join(dirpath, filename))
    return(fastq_files)


def FindInputReads(wildcards):
    # globals
    stage_rep_to_sample_number = {
        'PBM_1': '1',
        'PBM_2': '2',
        'PBM_3': '3',
        'SM_1': '4',
        'SM_2': '5',
        'SM_3': '6'}
    species_code_to_letter = {
        'osj': 'J',
        'osi': 'I',
        'ob': 'B',
        'or': 'R',
        'og': 'G'}
    my_stage = wildcards.stage
    my_species = wildcards.species
    my_rep = wildcards.rep
    my_sample_number = stage_rep_to_sample_number[
        '_'.join([my_stage, my_rep])]
    my_letter = species_code_to_letter[my_species]
    my_fastq_name = ''.join([my_letter, my_sample_number])
    my_r1 = [x for x in all_fastq_files
             if('R1' in os.path.basename(x)
                and os.path.basename(x).startswith(my_fastq_name))][0]
    my_r2 = [x for x in all_fastq_files
             if('R2' in os.path.basename(x)
                and os.path.basename(x).startswith(my_fastq_name))][0]
    return({'r1': my_r1, 'r2': my_r2})


###########
# GLOBALS #
###########

singularity_container = ('shub://TomHarrop/'
                         'singularity-containers:five-accessions'
                         '@ae9d367dd147e8c013f143fc96ade097')


os_genome = 'data/genome/os/Osativa_323_v7.0.fa'
os_gff = 'data/genome/os/Osativa_323_v7.0.gene_exons.gff3'
os_gtf = 'output/010_data/Osativa_323_v7.0.gene_exons.cuffcomp.rRNAremoved.gtf'
read_dir = 'data/reads'
all_species = ['osj',
               'osi',
               'ob',
               'or',
               'og']
all_reps = ['1', '2', '3']
all_stages = ['PBM', 'SM']

all_de_files = ['domestication',
                'stage_accession_japonica',
                'stage_accession_indica',
                'stage_accession_glaberrima',
                'stage_between_species',
                'stage_within_species',
                'stage_continent_africa',
                'stage_continent_asia',
                'accession',
                'stage']

#########
# SETUP #
#########

all_fastq_files = FindAllFastqFiles(read_dir)

#########
# RULES #
#########

rule target:
    input:
        'output/070_clustering/tfs/annotated_clusters_scaled_l2fc.csv',
        'output/070_clustering/all/annotated_clusters_scaled_l2fc.csv',
        'output/050_deseq/wald_tests/expr_genes/sig/domestication.csv',
        'output/050_deseq/wald_tests/tfs/sig/domestication.csv',
        'output/080_phenotype/cali_cluster_correlation.csv'

# 080 correlations with phenotypic data
rule correlate_clusters_to_cali:
    input:
        cali = 'output/080_phenotype/cali.csv',
        clusters = ('output/070_clustering/tfs/'
                    'annotated_clusters_scaled_l2fc.csv')
    output:
        correlation = 'output/080_phenotype/cali_cluster_correlation.csv'
        pca = 'output/080_phenotype/cali_pca.Rds'
    threads:
        1  
    log:
        log = 'output/000_logs/080_phenotype/correlate_clusters_to_cali.log'
    benchmark:
        'output/001_bench/080_phenotype/correlate_clusters_to_cali.tsv'
    singularity:
        singularity_container
    script:
        'src/correlate_clusters_to_cali.R'


rule correlate_clusters_to_mtp:
    input:
        mtp = 'output/080_phenotype/mtp.csv',
        clusters = ('output/070_clustering/tfs/'
                    'annotated_clusters_scaled_l2fc.csv')
    output:
        correlation = 'output/080_phenotype/mtp_cluster_correlation.csv'
    threads:
        1  
    log:
        log = 'output/000_logs/080_phenotype/correlate_clusters_to_mtp.log'
    benchmark:
        'output/001_bench/080_phenotype/correlate_clusters_to_mtp.tsv'
    singularity:
        singularity_container
    script:
        'src/correlate_clusters_to_mtp.R'

rule tidy_phenotype_data:
    input:
        mtp = 'data/phenotyping/Phenotype_PanicleSequenced_corrected2.csv',
        cali = 'data/phenotyping/OsOgObOrPTRAPdata_PaperTom.txt'
    output:
        mtp = 'output/080_phenotype/mtp.csv',
        cali = 'output/080_phenotype/cali.csv'
    threads:
        1
    log:
        log = 'output/000_logs/080_phenotype/tidy_phenotype_data.log'
    benchmark:
        'output/001_bench/080_phenotype/tidy_phenotype_data.tsv'
    singularity:
        singularity_container
    script:
        'src/tidy_phenotype_data.R'


# 070 clusters
rule mfuzz_tfs_stat:
    input:
        dds = 'output/050_deseq/dds_tfs.Rds',
        tfdb = 'output/010_data/tfdb.Rds'
    output:
        cluster_plot = 'output/070_clustering/tfs_stat/clusters.pdf',
        hyper = 'output/070_clustering/tfs_stat/hypergeom.csv',
        clusters = ('output/070_clustering/tfs_stat/'
                    'annotated_clusters_scaled_zstat.csv')
    params:
        alpha = 0.1,
        lfc_threshold = 0.5849625,  # log(1.5, 2)
        seed = 1
    threads:
        10
    log:
        log = 'output/000_logs/070_clustering/mfuzz_stat_tfs.log'
    benchmark:
        'output/001_bench/070_clustering/mfuzz_stat_tfs.tsv'
    singularity:
        singularity_container
    script:
        'src/mfuzz_stat_tfs.R'

rule mfuzz_tfs:
    input:
        dds = 'output/050_deseq/dds_tfs.Rds',
        tfdb = 'output/010_data/tfdb.Rds'
    output:
        cluster_plot = 'output/070_clustering/tfs/clusters.pdf',
        hyper = 'output/070_clustering/tfs/hypergeom.csv',
        clusters = ('output/070_clustering/tfs/'
                    'annotated_clusters_scaled_l2fc.csv')
    params:
        alpha = 0.1,
        lfc_threshold = 0.5849625,  # log(1.5, 2)
        seed = 1
    threads:
        10
    log:
        log = 'output/000_logs/070_clustering/mfuzz_tfs.log'
    benchmark:
        'output/001_bench/070_clustering/mfuzz_tfs.tsv'
    singularity:
        singularity_container
    script:
        'src/mfuzz_tfs.R'

rule mfuzz_all:
    input:
        dds = 'output/050_deseq/filtered_dds.Rds',
        tfdb = 'output/010_data/tfdb.Rds'
    output:
        cluster_plot = 'output/070_clustering/all/clusters.pdf',
        hyper = 'output/070_clustering/all/hypergeom.csv',
        clusters = ('output/070_clustering/all/'
                    'annotated_clusters_scaled_l2fc.csv')
    params:
        alpha = 0.1,
        lfc_threshold = 0.5849625,  # log(1.5, 2)
        seed = 1
    threads:
        10
    log:
        log = 'output/000_logs/070_clustering/mfuzz_all.log'
    benchmark:
        'output/001_bench/070_clustering/mfuzz_all.tsv'
    singularity:
        singularity_container
    script:
        'src/mfuzz_all.R'

# 060 calculate TPM
rule calculate_cutoffs:
    input:
        norm_counts = 'output/050_deseq/norm_counts.Rds',
        star_logs = 'output/030_mapping/stats/star_logs.Rds',
        bg_dds = 'output/040_background-counts/dds_background.Rds',
        feature_lengths = 'output/010_data/feature_lengths.Rds',
        tpm = 'output/060_tpm/tpm.Rds'
    output:
        tpm_with_calls = 'output/060_tpm/tpm_with_calls.Rds',
        detected_genes = 'output/060_tpm/detected_genes.Rds'
    threads:
        1
    log:
        log = 'output/000_logs/060_tpm/calculate_cutoffs.log'
    benchmark:
        'output/001_bench/060_tpm/calculate_cutoffs.tsv'
    singularity:
        singularity_container
    script:
        'src/calculate_cutoffs.R'

rule calculate_tpm:
    input:
        feature_lengths = 'output/010_data/feature_lengths.Rds',
        star_logs = 'output/030_mapping/stats/star_logs.Rds',
        norm_counts = 'output/050_deseq/norm_counts.Rds'
    output:
        tpm = 'output/060_tpm/tpm.Rds',
        tpm_wide = 'output/060_tpm/tpm_wide.Rds',
        csv = 'output/060_tpm/tpm.csv'
    log:
        log = 'output/000_logs/060_tpm/calculate_tpm.log'
    benchmark:
        'output/001_bench/060_tpm/calculate_tpm.tsv'
    threads:
        1
    singularity:
        singularity_container
    script:
        'src/calculate_tpm.R'

# 050 DEseq2
rule deseq_tfs:
    input:
        dds = 'output/050_deseq/dds_tfs.Rds'
    output:
        expand('output/050_deseq/wald_tests/tfs/{cutoff}/{de_file}.csv',
               cutoff=['all', 'sig'],
               de_file=all_de_files)
    params:
        all_outdir = 'output/050_deseq/wald_tests/tfs/all',
        sig_outdir = 'output/050_deseq/wald_tests/tfs/sig',
        alpha = 0.1,
        lfc_threshold = 0.5849625 # log(1.5, 2)
    threads:
        10
    log:
        log = 'output/000_logs/050_deseq/deseq_tfs.log'
    benchmark:
        'output/001_bench/050_deseq/deseq_tfs.tsv'
    singularity:
        singularity_container
    script:
        'src/deseq_wald.R'

rule deseq_expr:
    input:
        dds = 'output/050_deseq/filtered_dds.Rds'
    output:
        expand('output/050_deseq/wald_tests/expr_genes/{cutoff}/{de_file}.csv',
               cutoff=['all', 'sig'],
               de_file=all_de_files)
    params:
        all_outdir = 'output/050_deseq/wald_tests/expr_genes/all',
        sig_outdir = 'output/050_deseq/wald_tests/expr_genes/sig',
        alpha = 0.1,
        lfc_threshold = 0.5849625 # log(1.5, 2)
    threads:
        10
    log:
        log = 'output/000_logs/050_deseq/deseq_expr.log'
    benchmark:
        'output/001_bench/050_deseq/deseq_expr.tsv'
    singularity:
        singularity_container
    script:
        'src/deseq_wald.R'

rule filter_tfs:
    input:
        tfdb = 'output/010_data/tfdb.Rds',
        detected_genes = 'output/060_tpm/detected_genes.Rds',
        dds = 'output/050_deseq/dds.Rds'
    output:
        dds = 'output/050_deseq/dds_tfs.Rds'
    threads:
        1
    log:
        log = 'output/000_logs/050_deseq/filter_tfs.log'
    benchmark:
        'output/001_bench/050_deseq/filter_tfs.tsv'
    singularity:
        singularity_container
    script:
        'src/filter_tfs.R'

rule filter_deseq_object:
    input:
        dds = 'output/050_deseq/dds.Rds',
        detected_genes = 'output/060_tpm/detected_genes.Rds'
    output:
        dds = 'output/050_deseq/filtered_dds.Rds'
    threads:
        50
    log:
        log = 'output/000_logs/050_deseq/filter_deseq_object.log'
    benchmark:
        'output/001_bench/050_deseq/filter_deseq_object.tsv'
    singularity:
        singularity_container
    script:
        'src/filter_deseq_object.R'


rule generate_deseq_object:
    input:
        read_count_list = expand(
            ('output/030_mapping/star-pass2/{species}/'
             '{stage}_{rep}.ReadsPerGene.out.tab'),
            species=all_species,
            stage=all_stages,
            rep=all_reps)
    output:
        dds = 'output/050_deseq/dds.Rds',
        vst = 'output/050_deseq/vst.Rds',
        rld = 'output/050_deseq/rld.Rds',
        norm_counts = 'output/050_deseq/norm_counts.Rds'
    log:
        log = 'output/000_logs/050_deseq/generate_deseq_object.log'
    benchmark:
        'output/001_bench/050_deseq/generate_deseq_object.tsv'
    threads:
        10
    singularity:
        singularity_container
    script:
        'src/generate_deseq_object.R'


# 040 count background
rule combine_background_counts:
    input:
        count_files = expand(
            ('output/040_background-counts/'
             '{species}/{stage}_{rep}.htseq-count'),
            species=all_species,
            stage=all_stages,
            rep=all_reps)
    output:
        counts = 'output/040_background-counts/all_counts.Rds',
        dds = 'output/040_background-counts/dds_background.Rds'
    log:
        log = ('output/000_logs/040_background-counts/'
               'combine_background_counts.log')
    benchmark:
        ('output/001_bench/040_background-counts/'
         'combine_background_counts.tsv')
    threads:
        1
    singularity:
        singularity_container
    script:
        'src/combine_background_counts.R'


rule count_background:
    input:
        bam = ('output/030_mapping/star-pass2/{species}/'
               '{stage}_{rep}.Aligned.out.bam'),
        shuffled_gff = 'output/010_data/shuffle/shuffed.gff3'
    output:
        counts = ('output/040_background-counts/'
                  '{species}/{stage}_{rep}.htseq-count')
    log:
        'output/000_logs/040_background-counts/{species}_{stage}_{rep}.log'
    benchmark:
        'output/001_bench/040_background-counts/{species}_{stage}_{rep}.tsv'
    threads:
        1
    singularity:
        singularity_container
    shell:
        'htseq-count '
        '-t CDS '
        '-f bam '
        '-s reverse '
        '-i ID '
        '-r name '
        '{input.bam} '
        '{input.shuffled_gff} '
        '> {output.counts} '
        '2> {log}'

# 030 map
rule parse_star_logs:
    input:
        log_file_list = expand(
            ('output/030_mapping/star-pass2/{species}/'
             '{stage}_{rep}.Log.final.out'),
            species=all_species,
            stage=all_stages,
            rep=all_reps),
        read_count_list = expand(
            ('output/030_mapping/star-pass2/{species}/'
             '{stage}_{rep}.ReadsPerGene.out.tab'),
            species=all_species,
            stage=all_stages,
            rep=all_reps)
    output:
        csv = 'output/030_mapping/stats/star_logs.csv',
        rds = 'output/030_mapping/stats/star_logs.Rds'
    threads:
        1
    log:
        log = 'output/000_logs/030_mapping/parse_star_logs.log'
    benchmark:
        'output/001_bench/030_mapping/parse_star_logs.tsv'
    singularity:
        singularity_container
    script:
        'src/parse_star_logs.R'


rule second_mapping:
    input:
        r1 = 'output/021_trim-reads/{species}/{stage}_{rep}.r1.fastq.gz',
        r2 = 'output/021_trim-reads/{species}/{stage}_{rep}.r2.fastq.gz',
        genome = 'output/010_data/star-index/SA',
        sjs = expand(('output/030_mapping/star-pass1/{{species}}/'
                      '{stage}_{rep}.SJ.out.tab'),
                     stage=all_stages,
                     rep=all_reps)
    output:
        ('output/030_mapping/star-pass2/{species}/'
         '{stage}_{rep}.ReadsPerGene.out.tab'),
        ('output/030_mapping/star-pass2/{species}/'
         '{stage}_{rep}.Aligned.out.bam'),
        ('output/030_mapping/star-pass2/{species}/'
         '{stage}_{rep}.Log.final.out')
    threads:
        20
    resources:
        mem_gb = 40
    params:
        genome_dir = 'output/010_data/star-index',
        prefix = 'output/030_mapping/star-pass2/{species}/{stage}_{rep}.'
    log:
        'output/000_logs/030_mapping/{species}-{stage}-{rep}_pass2.log'
    benchmark:
        'output/001_bench/030_mapping/{species}-{stage}-{rep}_pass2.tsv'
    singularity:
        singularity_container
    shell:
        'STAR '
        '--sjdbFileChrStartEnd {input.sjs} '
        '--runThreadN {threads} '
        '--genomeDir {params.genome_dir} '
        '--outSJfilterReads Unique '
        '--readFilesCommand zcat '
        '--outSAMtype BAM Unsorted '
        '--quantMode GeneCounts '
        '--outBAMcompression 10 '
        '--outReadsUnmapped Fastx '
        '--readFilesIn {input.r1} {input.r2} '
        '--outFileNamePrefix {params.prefix} '
        '&> {log}'


rule first_mapping:
    input:
        r1 = 'output/021_trim-reads/{species}/{stage}_{rep}.r1.fastq.gz',
        r2 = 'output/021_trim-reads/{species}/{stage}_{rep}.r2.fastq.gz',
        genome = 'output/010_data/star-index/SA'
    output:
        'output/030_mapping/star-pass1/{species}/{stage}_{rep}.SJ.out.tab'
    threads:
        50
    resources:
        mem_gb = 40
    params:
        genome_dir = 'output/010_data/star-index',
        prefix = 'output/030_mapping/star-pass1/{species}/{stage}_{rep}.'
    log:
        'output/000_logs/030_mapping/{species}-{stage}-{rep}_pass1.log'
    benchmark:
        'output/001_bench/030_mapping/{species}-{stage}-{rep}_pass1.tsv'
    singularity:
        singularity_container
    shell:
        'STAR '
        '--runThreadN {threads} '
        '--genomeDir {params.genome_dir} '
        '--outSJfilterReads Unique '
        '--readFilesCommand zcat '
        '--outSAMtype None '
        '--readFilesIn {input.r1} {input.r2} '
        '--outFileNamePrefix {params.prefix} '
        '&> {log}'


# 020 trim reads
rule gzip:
    input:
        'output/021_trim-reads/{species}/{stage}_{rep}.r{n}.fastq'
    output:
        'output/021_trim-reads/{species}/{stage}_{rep}.r{n}.fastq.gz'
    threads:
        1
    singularity:
        singularity_container
    shell:
        'cat {input} | gzip -9 > {output}'

rule cutadapt:
    input:
        r1 = 'output/020_repair/{species}/{stage}_{rep}.r1.fastq',
        r2 = 'output/020_repair/{species}/{stage}_{rep}.r2.fastq'
    output:
        r1 = temp('output/021_trim-reads/{species}/{stage}_{rep}.r1.fastq'),
        r2 = temp('output/021_trim-reads/{species}/{stage}_{rep}.r2.fastq')
    threads:
        1
    log:
        'output/000_logs/021_trim-reads/{species}_{stage}_{rep}.log'
    benchmark:
        'output/001_bench/021_trim-reads/{species}_{stage}_{rep}.tsv'
    singularity:
        singularity_container
    shell:
        'cutadapt '
        '-a \'TruSeq_adaptor=AGATCGGAAGAGCACACGTCTGAACTCCAGTC\' '
        '-A \'Illumina_single_end=AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTG\' '
        '--quality-cutoff=20 '
        '--minimum-length=50 '
        '--output={output.r1} '
        '--paired-output={output.r2} '
        '{input.r1} {input.r2} '
        '&> {log}'


rule repair:
    input:
        unpack(FindInputReads)
    output:
        r1 = temp('output/020_repair/{species}/{stage}_{rep}.r1.fastq'),
        r2 = temp('output/020_repair/{species}/{stage}_{rep}.r2.fastq')
    threads:
        1
    resources:
        mem_gb = 50
    log:
        'output/000_logs/020_repair/{species}_{stage}_{rep}.log'
    benchmark:
        'output/001_bench/020_repair/{species}_{stage}_{rep}.tsv'
    singularity:
        singularity_container
    shell:
        'repair.sh '
        'in={input.r1} '
        'in2={input.r2} '
        'out={output.r1} '
        'out2={output.r2} '
        'zl=9 '
        'repair=t '
        '-Xmx{resources.mem_gb}g '
        '2> {log}'


# 010 prepare data
rule format_tfdb:
    input:
        tfdb_file = 'data/genome/os/tfdb.tab'
    output:
        tfdb_file = 'output/010_data/tfdb.Rds'
    threads:
        1
    log:
        log = 'output/000_logs/010_prepare-data/format_tfdb.log'
    benchmark:
        'output/001_bench/010_prepare-data/format_tfdb.tsv'
    singularity:
        singularity_container
    script:
        'src/format_tfdb.R'

rule shuffle_gtf:
    input:
        os_gff_file = 'data/genome/os/Osativa_323_v7.0.gene_exons.gff3',
        os_gtf_file = ('output/010_data/'
                       'Osativa_323_v7.0.gene_exons.cuffcomp.rRNAremoved.gtf'),
        seqlengths_file = 'output/010_data/star-index/chrNameLength.txt',
        irgsp_gff_file = 'data/genome/os/irgsp1_rRNA_tRNA.gff',
        osa1r7_gff_file = 'data/genome/os/rice_osa1r7_rm.gff3',
        osa1_mirbase_gff_file = 'data/genome/os/osa.gff3',
        tigr_repeats_fa = 'data/genome/os/TIGR_Oryza_Repeats.v3.3_0_0.fsa'
    params:
        star_index_dir = 'output/010_data/star-index'
    threads:
        10
    output:
        shuffled_gff = 'output/010_data/shuffle/shuffed.gff3'
    log:
        log = 'output/000_logs/010_prepare-data/shuffle_gtf.log'
    benchmark:
        'output/001_bench/010_prepare-data/shuffle_gtf.tsv'
    singularity:
        singularity_container
    script:
        'src/shuffle_gtf.R'

rule calculate_feature_lengths:
    input:
        os_gtf_file = ('output/010_data/'
                       'Osativa_323_v7.0.gene_exons.cuffcomp.rRNAremoved.gtf'),
    output:
        feature_lengths = 'output/010_data/feature_lengths.Rds'
    threads:
        1
    log:
        log = 'output/000_logs/010_prepare-data/calculate_feature_lengths.log'
    benchmark:
        'output/001_bench/010_prepare-data/calculate_feature_lengths.tsv'
    singularity:
        singularity_container
    script:
        'src/calculate_feature_lengths.R'


rule generate_genome:
    input:
        os_genome = os_genome,
        os_gtf = os_gtf
    output:
        'output/010_data/star-index/SA',
        'output/010_data/star-index/chrNameLength.txt'
    params:
        outdir = 'output/010_data/star-index'
    threads:
        50
    log:
        'output/000_logs/010_prepare-data/generate_genome.log'
    benchmark:
        'output/001_bench/010_prepare-data/generate_genome.tsv'
    singularity:
        singularity_container
    shell:
        'STAR '
        '--runThreadN {threads} '
        '--runMode genomeGenerate '
        '--genomeDir {params.outdir} '
        '--genomeFastaFiles {input.os_genome} '
        '--sjdbGTFfile {input.os_gtf} '
        '--sjdbGTFtagExonParentTranscript oId '
        '--sjdbGTFtagExonParentGene gene_name '
        '--sjdbOverhang 109 '
        '--outFileNamePrefix {params.outdir}/ '
        '&> {log}'

rule generate_gtf:
    input:
        os_genome = os_genome,
        os_gff = os_gff,
    output:
        os_gtf = os_gtf,
        cuffcomp_gtf = temp('output/010_data/cuffcomp/'
                            'annot.cuffcomp.combined.gtf')
    params:
        cuffcomp_dir = 'output/010_data/cuffcomp'
    threads:
        1
    log:
        'output/000_logs/010_prepare-data/generate_gtf.log'
    log:
        'output/001_bench/010_prepare-data/generate_gtf.tsv'
    singularity:
        singularity_container
    shell:
        'cuffcompare '
        '-s {input.os_genome} '
        '-CG '
        '-r {input.os_gff} '
        '-o {params.cuffcomp_dir}/annot.cuffcomp '
        '{input.os_gff} '
        '&> {log} ; '
        'sed \'/LOC_Os09g01000/d\' '
        '{output.cuffcomp_gtf} '
        ' | sed \'/LOC_Os09g00999/d\' '
        '> {output.os_gtf}'
