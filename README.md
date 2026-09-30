# runner-budget

Use your GitHub org's included Actions minutes first. When they run low, send CI to
[Blacksmith](https://blacksmith.sh) runners and use its free minutes too. On the 1st of
the month, CI goes back to GitHub.

One hourly job reads the org's minutes from GitHub's billing API. It sets a `CI_RUNNER`
variable in each repo. Workflows read that variable in `runs-on`:

```yaml
runs-on: ${{ vars.CI_RUNNER || 'ubuntu-latest' }}
```

## Install

You need `gh` (logged in as an org owner), `curl`, and `jq`. Install the Blacksmith GitHub
App on the org first.

```sh
curl -fsSL https://raw.githubusercontent.com/aperswal/runner-budget/main/runner-budget -o runner-budget
chmod +x runner-budget
./runner-budget check --org my-org
./runner-budget install --org my-org --repos api,web --dry-run
./runner-budget install --org my-org --repos api,web
```

`install` does four things:

1. It sets `CI_RUNNER` and `CI_RUNNER_SMALL` in each repo, based on this month's usage.
2. It asks you for a classic personal access token and saves it as the
   `RUNNER_BUDGET_PAT` secret. The token needs the `repo` scope and must belong to an org
   owner. GitHub's billing API does not accept fine-grained tokens.
3. It opens a PR in the first repo. The PR adds the hourly workflow and a copy of this
   script.
4. It opens a PR in each repo that changes `runs-on: ubuntu-latest` to read `CI_RUNNER`.
   It leaves every other `runs-on` value alone.

## Options

| Option | Default | Meaning |
|---|---|---|
| `--threshold N` | included minutes minus 200 | Switch to Blacksmith at this many minutes used |
| `--overflow LABEL` | `blacksmith-2vcpu-ubuntu-2404` | Runner for CI after the switch |
| `--overflow-small LABEL` | `blacksmith-2vcpu-ubuntu-2404` | Runner for small jobs and for the hourly job |
| `--selector-repo REPO` | first repo in `--repos` | Repo that holds the hourly job and the secret |
| `--dry-run` | off | Print the changes and make none |

The 200-minute margin covers jobs that were already queued when the switch happens. Jobs
that are already queued keep their runner.

## Develop

```sh
test/run.sh   # runs bats tests and shellcheck in Docker
```
