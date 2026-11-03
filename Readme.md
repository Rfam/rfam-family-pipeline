# Rfam family-building pipeline

Tools for building, curating, checking, and publishing RNA families. The pipeline combines sequence searches, covariance models, alignments, annotation thresholds, and quality control with Rfam database and SVN workflows.

Use Docker for local development or Apptainer for environments such as HPC clusters. Reference databases, credentials, scheduler integration, and SVN services must be configured for your deployment.

## Requirements

- Git and Bash.
- Docker for building the container image.
- Apptainer on the machine that builds or runs a SIF image, if using that runtime.
- Access to the sequence data and services required by the commands you intend to run.

A container supplies software dependencies; it does not automatically provide production data or access to Rfam services.

## Get the source

```bash
git clone https://github.com/Rfam/rfam-family-pipeline.git
cd rfam-family-pipeline
export PIPELINE_DIR="$(pwd -P)"
```

For an existing checkout, run the last command from its root directory.

## Configure your environment

Run the examples in Bash. Set these variables once in the host shell, replacing the placeholder values before continuing. Use absolute paths for host files and directories.

```bash
export IMAGE_NAME='<image-name>:<tag>'
export PLATFORM='<target-platform>'
export WORK_DIR='<absolute-path-to-working-directory>'
export CONFIG_FILE='<absolute-path-to-rfam-config>'
export IMAGE_ARCHIVE='<absolute-path-to-docker-archive.tar>'
export SIF_IMAGE='<absolute-path-to-container.sif>'
export CONTAINER_RUNTIME='apptainer'

# These destinations must agree with the image layout and your configuration.
export CONTAINER_PIPELINE_DIR='/Rfam/rfam-family-pipeline'
export CONTAINER_WORK_DIR='/workdir'
export CONTAINER_CONFIG_FILE='/tmp/rfam.conf'
```

`CONTAINER_PIPELINE_DIR` reflects the layout used by the supplied workflow. Changing it alone does not relocate software installed in the image: check the Dockerfile, image environment, and configuration before choosing another destination. The work and config destinations can be changed consistently across these examples.

Choose a platform supported by the Dockerfile and target machine. The supplied CI workflow builds `linux/amd64`; do not assume that all bundled tools support other architectures.

Create the work directory and check the config before launching a container:

```bash
mkdir -p "$WORK_DIR"
test -d "$PIPELINE_DIR/Rfam/Tests"
test -f "$CONFIG_FILE"
```

Prepare your configuration from the repository's configuration examples. Set database connection details, sequence database locations, SVN endpoints, and scheduler settings for your environment. File paths in the configuration must resolve **inside the container**. Bind any additional data directories at those paths.

Keep credentials and private configuration outside version control. `RFAM_CONFIG` selects the configuration file; changing environment variables such as a database host does not automatically rewrite that file.

## Docker

### Build the image

```bash
docker build \
  --platform "$PLATFORM" \
  --tag "$IMAGE_NAME" \
  --file "$PIPELINE_DIR/Dockerfile" \
  "$PIPELINE_DIR"
```

Or get the prebuilt image by:
```docker pull rfam/family-pipeline:<tag>```

### Open a working shell

```bash
docker run --rm -it \
  --platform "$PLATFORM" \
  --volume "$PIPELINE_DIR:$CONTAINER_PIPELINE_DIR:rw" \
  --volume "$WORK_DIR:$CONTAINER_WORK_DIR:rw" \
  --volume "$CONFIG_FILE:$CONTAINER_CONFIG_FILE:ro" \
  --workdir "$CONTAINER_WORK_DIR" \
  --env RFAM_CONFIG="$CONTAINER_CONFIG_FILE" \
  "$IMAGE_NAME" bash
```

Work saved in the mounted work directory persists after the container exits. The source checkout is writable because some pipeline commands and tests create files beneath it.

Inside the container, check that the expected tools are available:

```bash
command -v cmsearch hmmsearch mafft perl prove
test -r "$RFAM_CONFIG"
```

Use the environment supplied by the image. If you need additional Perl modules, extend its `PERL5LIB` rather than replacing it with host-specific library paths.

## Apptainer

### Convert the Docker image

On a machine with Docker, export the image:

```bash
docker save --output "$IMAGE_ARCHIVE" "$IMAGE_NAME"
```

On a machine with Apptainer, convert the archive:

```bash
"$CONTAINER_RUNTIME" build "$SIF_IMAGE" "docker-archive:$IMAGE_ARCHIVE"
"$CONTAINER_RUNTIME" inspect "$SIF_IMAGE"
```

If these are different machines, transfer the archive and update `IMAGE_ARCHIVE` on the destination first. Set the required variables again in each new shell. The resulting image must be compatible with the target machine's architecture.

### Open a working shell

```bash
"$CONTAINER_RUNTIME" exec --cleanenv \
  --bind "$PIPELINE_DIR:$CONTAINER_PIPELINE_DIR:rw" \
  --bind "$WORK_DIR:$CONTAINER_WORK_DIR:rw" \
  --bind "$CONFIG_FILE:$CONTAINER_CONFIG_FILE:ro" \
  --pwd "$CONTAINER_WORK_DIR" \
  --env RFAM_CONFIG="$CONTAINER_CONFIG_FILE" \
  "$SIF_IMAGE" bash
```

`--cleanenv` limits inherited host environment variables; the image's environment and runtime-provided variables still apply. Pass deployment-specific variables explicitly.

The SIF image can remain immutable while bound host directories are writable. All bind sources must exist before the command starts, and your host account must have permission to access them.

If your site provides Singularity instead of Apptainer, set `CONTAINER_RUNTIME` to its executable and verify that the installed version supports the flags used here.

## Run the tests

The test suite includes file operations and database access. Use a disposable checkout and a dedicated test database. Prepare the database with `Rfam/Tests/data/setup_test_db.sql` and use `Rfam/Tests/rfam_test.conf` as the starting point for a separate test configuration.

Set its path on the host:

```bash
export TEST_CONFIG_FILE='<absolute-path-to-test-config>'
test -f "$TEST_CONFIG_FILE"
```

Configure the database host, port, credentials, and authentication method for the test runtime. Docker networking and Apptainer networking may require different host settings; use separate config files when needed. Load the SQL fixture into the intended test database before running the suite.

### Docker tests

```bash
docker run --rm \
  --platform "$PLATFORM" \
  --volume "$PIPELINE_DIR:$CONTAINER_PIPELINE_DIR:rw" \
  --volume "$TEST_CONFIG_FILE:$CONTAINER_CONFIG_FILE:ro" \
  --workdir "$CONTAINER_PIPELINE_DIR/Rfam/Tests" \
  --env RFAM_CONFIG="$CONTAINER_CONFIG_FILE" \
  "$IMAGE_NAME" bash -c 'prove --jobs=1 *.t'
```

Add the Docker network options required to reach your test database. For the Linux CI arrangement discussed here, a database published on the runner is reached using `--network host` and the published port in the test configuration. Do not assume the same networking setup on every workstation.

### Apptainer tests

```bash
"$CONTAINER_RUNTIME" exec --cleanenv \
  --bind "$PIPELINE_DIR:$CONTAINER_PIPELINE_DIR:rw" \
  --bind "$TEST_CONFIG_FILE:$CONTAINER_CONFIG_FILE:ro" \
  --pwd "$CONTAINER_PIPELINE_DIR/Rfam/Tests" \
  --env RFAM_CONFIG="$CONTAINER_CONFIG_FILE" \
  "$SIF_IMAGE" bash -c 'prove --jobs=1 *.t'
```

Keep the checkout writable and tests sequential: the suite writes models, indexes, alignments, and temporary files in the test tree. In CI, create the configuration and its parent directory in the same job that runs the tests. Temporary files are not shared automatically between jobs.

## HPC and Slurm

Cluster integration depends on the site's scheduler, authentication, libraries, and filesystem layout. Use your cluster's supported container setup rather than copying paths from another deployment.

Two common approaches are:

- Submit a batch script from the host and run the container inside the allocated job.
- Submit jobs from inside the container using a site-supported Slurm client environment.

The second approach may require compatible client binaries, libraries and plugins, scheduler configuration, and access to the site's authentication service. Ask the cluster administrators for the required bind paths and environment variables. Binding an individual scheduler binary may not provide all of its dependencies.

If the site uses Munge, follow its client authentication setup. Do not copy a Munge secret key into the image or assume users should mount the key. Keep scheduler mounts and settings in a local launcher or batch script.

## Family curation

A typical workflow is:

1. Create a family with `rfnew.pl`, or check out an existing family with `rfco.pl`.
2. Prepare the `SEED` alignment in Stockholm format.
3. Build a covariance model with `cmbuild --hand CM SEED`.
4. Calibrate the model with `cmcalibrate CM`.
5. Run the configured search and build workflow with `rfmake.pl`.
6. Refine the alignment and annotations, then rebuild and search as needed.
7. Run quality control and resolve failures.
8. Commit through the configured Rfam SVN workflow.

For commands that take a family identifier or commit message, set your own values:

```bash
export FAMILY_ID='<family-identifier>'
export COMMIT_MESSAGE='<description-of-changes>'

rfco.pl "$FAMILY_ID"
# Curate the checked-out family and run the required checks.
rfci.pl "$FAMILY_ID" -m "$COMMIT_MESSAGE"
```

Command arguments and working-directory requirements depend on the script. Check the usage output and repository documentation before running a production operation.

## SVN deployment and hooks

SVN URLs and database connections belong in the deployment configuration. Configure authentication for the account that actually runs the client or service; host credentials are not automatically available in every container setup.

Hooks run on the **SVN server**, under the server's execution environment. Starting an interactive pipeline container does not install hooks or make server hooks execute inside it.

Administrators should configure the repository's executable `hooks/pre-commit` and `hooks/post-commit` entry points to invoke the appropriate pipeline scripts:

| Entry point | Pipeline script | Inputs |
| --- | --- | --- |
| `pre-commit` | `Rfam/Scripts/svnhooks/pre-commit.pl` | Repository path and transaction name |
| `post-commit` | `Rfam/Scripts/svnhooks/post-commit.pl` | Repository path and revision |

Keep the pipeline location, Perl executable, config file, module paths, and optional notification settings in a deployment-managed configuration that each wrapper explicitly loads. Hooks must not depend on an interactive shell profile. If a wrapper launches a container, it must bind the repository and required configuration into that container and pass paths the container can resolve.

Pre-commit checks can reject a transaction. A post-commit failure occurs after the revision has been committed; report the failure and repair any incomplete downstream synchronization rather than assuming the commit was rolled back. Preserve hook exit statuses instead of unconditionally ending wrappers with `exit 0`.

Rfam's hook logic uses structured commit messages. Use the pipeline's client commands and check the hook source for supported operations. Errors about a missing or unrecognized commit message require inspection of the client invocation, message format, and hook arguments; they do not by themselves prove that hooks are missing.

Optional Slack or email notifications are deployment integrations. Configure them separately from the core hook logic.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| `mount source ... doesn't exist` | Create the host source before starting the container. Check variable expansion and whether the file was created in a different CI job. |
| `Read-only file system` while testing | Bind the checkout with `:rw` and confirm host write permissions. The config can remain `:ro`. |
| Unable to create a model, alignment, or SSI index | Check that the data directory is writable, then verify the required inputs exist. |
| `Bad plan` or fewer tests run than planned | Find the first error before the summary; an earlier failure may have stopped the test script. |
| Database connection or authentication failure | Check the container-visible host and port, database initialization, grants, and client/authentication compatibility. |
| Missing Perl module or executable | Check the image environment and whether host settings or mounts have overridden it. |
| Slurm commands fail inside the container | Check the site's supported client, library, configuration, and authentication setup. |
| Apptainer cleanup timeout after another error | Resolve the initial startup or test failure first; the timeout may be a cleanup symptom. |

## Documentation

- [Rfam documentation](https://docs.rfam.org)
- [Rfam website](https://rfam.org)
- [Docker documentation](https://docs.docker.com)
- [Apptainer bind mounts](https://apptainer.org/docs/user/latest/bind_paths_and_mounts.html)
- [Apptainer environment handling](https://apptainer.org/docs/user/latest/environment_and_metadata.html)
- [Subversion repository administration](https://svnbook.red-bean.com/en/1.8/svn.reposadmin.create.html)
