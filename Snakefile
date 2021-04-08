import os.path
import re
import subprocess
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider

HTTP = HTTPRemoteProvider()

# For testing, parse the yaml file (this is automatically done by Snakemake)
#import yaml
#with open("config/config.yaml", 'r') as ymlfile: config = yaml.safe_load(ymlfile)

configfile: "config/config.yaml"

# Find the maximum number of cores available to a single node on SLURM,
# or if we aren't in a SLURM environment, how many we have on the local machine.
try:
    maxthreads = max([int(x) for x in re.findall(r'\d+', subprocess.check_output(["sinfo", "-O", "cpus"]).decode())])
except FileNotFoundError:
    maxthreads = int(subprocess.check_output("nproc").decode())

#### Reference databases ####

# generate taxonomy translation files
localrules: translate_references
rule translate_references:
  output:
        expand("{outdir}/{db}.{region}.{method}.fasta.gz",
               outdir = config['outdir'],
               db = ['warcup', 'unite'],
               region = ['ITS'],
               method = ['sintax', 'dada2']),
        expand("{outdir}/{db}.{region}.{method}.fasta.gz",
               outdir = config['outdir'],
               db = ['rdp_train', 'silva'],
               region = ['LSU'],
               method = ['sintax', 'dada2'])
  input:
    expand("{refdir}/{dbname}.{type}",
           refdir = config['refdir'],
           dbname = ['rdp_train', 'warcup', 'unite', 'silva'],
           type = ['fasta.gz', 'pre.sed']),
    "{rdir}/taxonomy.R".format_map(config),
    regions = config["regions_file"],
    tedersoo = "{refdir}/Tedersoo_Eukarya_classification.xlsx".format_map(config),
    tedersoo_add = config['tedersoo_add'],
    tedersoo_patch = config['tedersoo_patch'],
    script = "{rdir}/make_taxonomy.R".format_map(config)
  resources:
    walltime = 60
  conda: "{condadir}/drake.yaml".format_map(config)
  log: "{logdir}/translate_references.log".format_map(config)
  script: "{rdir}/make_taxonomy.R".format_map(config)

def unite_url(wildcards) :
    return config['unite_{which}_url'.format(which = wildcards.which)]
def unite_md5(wildcards) :
    return config['unite_{which}_md5'.format(which = wildcards.which)]
def unite_basename(wildcards) :
    return os.path.basename(unite_url(wildcards))
def unite_filename(wildcards) :
    return config['unite_{which}_filename'.format(which = wildcards.which)]

# Download the Unite database, without global and 97% singletons
localrules: unite_download
rule unite_download:
    output: "{refdir}/unite_{{which}}.fasta.gz".format_map(config)
    wildcard_constraints:
      which = "(no)?single"
    params:
      url = unite_url,
      zipfile = unite_basename,
      md5 = unite_md5,
      fasta = unite_filename
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.zipfile} | md5sum -c -
        mkdir -p $(dirname {output})
        tar -xzf {params.zipfile} {params.fasta}
        gzip -c9 {params.fasta} > {output}
        """

# Download the Unite+INSD database
localrules: unite_insd_download
rule unite_insd_download:
    output: "{refdir}/unite_insd.fasta.gz".format_map(config)
    params:
        url = config['unite_insd_url'],
        md5 = config['unite_insd_md5'],
        fasta = os.path.basename(config['unite_insd_url'])
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.fasta} | md5sum -c -
        mkdir -p $(dirname {output})
        mv {params.fasta} {output}
        """

# Download the RDP fungal LSU training set
# This will also convert all sequences from RNA (Uu) to DNA (Tt)
localrules: rdp_download
rule rdp_download:
    output:
        fasta = "{refdir}/rdp_train.fasta.gz".format_map(config),
        taxa  = "{refdir}/rdp_train.taxa.txt".format_map(config)
    params:
        url = config['rdp_url'],
        md5 = config['rdp_md5'],
        zipfile = os.path.basename(config['rdp_url']),
        fasta = config['rdp_filename'],
        taxa = config['rdp_taxa']
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.zipfile} | md5sum -c -
        mkdir -p $(dirname {output.fasta})
        unzip {params.zipfile} {params.fasta} {params.taxa}
        sed '/^>/!y/uU/tT/' <{params.fasta} | gzip -c9 > {output.fasta}
        mv {params.taxa} {output.taxa}
        """

# Download the RDP fungal LSU database
# This will also convert all sequences from RNA (Uu) to DNA (Tt)
localrules: rdp_full_download
rule rdp_full_download:
    output:
        fasta = "{refdir}/rdp_28S.fasta.gz".format_map(config)
    params:
        url = config['rdp_full_url'],
        fasta = os.path.basename(config['rdp_full_url']),
        md5 = config['rdp_full_md5']
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.fasta} | md5sum -c -
        mkdir -p $(dirname {output.fasta})
        zcat {params.fasta} |
         sed '/^>/!y/uU/tT/' |
          gzip -c9 >{output.fasta}
        """



# Download the Warcup fungal ITS training set
localrules: warcup_download
rule warcup_download:
    output:
        fasta = "{refdir}/warcup.fasta.gz".format_map(config),
        taxa  = "{refdir}/warcup.taxa.txt".format_map(config)
    params:
      url = config['warcup_url'],
      basename = os.path.basename(config['warcup_url']),
      md5 = config['warcup_md5'],
      filename = config['warcup_filename'],
      taxa = config['warcup_taxa']
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.basename} | md5sum -c -
        mkdir -p $(dirname {output.fasta})
        unzip {params.basename} {params.filename} {params.taxa}
        gzip -c9 {params.filename} > {output.fasta}
        mv {params.taxa} {output.taxa}
        """

def silva_url(wildcards) :
    return config['silva_{which}_url'.format(which = wildcards.which)]
def silva_md5(wildcards) :
    return config['silva_{which}_md5'.format(which = wildcards.which)]
def silva_basename(wildcards) :
    return os.path.basename(silva_url(wildcards))

# Download SILVA
# also extract Eukaryotes only, and transcribe RNA to DNA
rule silva_download:
    output:
        fasta = "{refdir}/silva_{{which}}.fasta.gz".format_map(config)
    params:
        url = silva_url,
        md5 = silva_md5,
        basename = silva_basename
    wildcard_constraints:
        which = "(parc|ref|nr99)"
    shadow: "shallow"
    conda: "config/vsearch.yaml"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.basename} | md5sum -c -
        mkdir -p $(dirname {output.fasta})
        zcat {params.basename} |
         tr ' ' '$' |
         vsearch --fastx_getseqs - --label_word Eukaryota --fastaout - |
         tr '$' ' ' |
         sed '/^>/!y/Uu/Tt/' |
         gzip -c >{output.fasta}
        """

# Download Eukarya classification system proposed by Tedersoo
localrules: tedersoo_classification
rule tedersoo_classification:
    output: "{refdir}/Tedersoo_Eukarya_classification.xlsx".format_map(config)
    params:
        url = config['tedersoo_url'],
        filename = os.path.basename(config['tedersoo_url']),
        md5 = config['tedersoo_md5']
    shadow: "shallow"
    shell:
        """
        wget {params.url}
        echo {params.md5} {params.filename} | md5sum -c -
        mv {params.filename} {output}
        """
