#!/usr/bin/env bats

setup() {
  # shellcheck source=../runner-budget
  source "$BATS_TEST_DIRNAME/../runner-budget"
}

@test "included minutes follow the org plan" {
  [ "$(included_minutes_for_plan free)" = 2000 ]
  [ "$(included_minutes_for_plan Team)" = 3000 ]
  [ "$(included_minutes_for_plan enterprise)" = 50000 ]
  [ -z "$(included_minutes_for_plan something-new)" ]
}

@test "reads only Actions minutes from the billing usage body" {
  body='{"usageItems":[
    {"product":"Actions","unitType":"Minutes","quantity":812.5},
    {"product":"actions","unitType":"minutes","quantity":100},
    {"product":"Actions","unitType":"GigabyteHours","quantity":999},
    {"product":"Packages","unitType":"Minutes","quantity":7}]}'
  [ "$(printf '%s' "$body" | actions_minutes_from_usage)" = 912 ]
}

@test "an empty month reads as zero minutes" {
  [ "$(printf '{"usageItems":[]}' | actions_minutes_from_usage)" = 0 ]
  [ "$(printf '{}' | actions_minutes_from_usage)" = 0 ]
}

@test "a body that is not JSON fails instead of reading as zero" {
  run bash -c "source '$BATS_TEST_DIRNAME/../runner-budget'; printf 'oops' | actions_minutes_from_usage"
  [ "$status" -ne 0 ]
  [ "$status" -ne 127 ]
}

@test "stays on the included fleet below the threshold" {
  [ "$(fleet_for_usage 2799 2800 bs-4 bs-2)" = "ubuntu-latest ubuntu-latest" ]
}

@test "overflows at and above the threshold" {
  [ "$(fleet_for_usage 2800 2800 bs-4 bs-2)" = "bs-4 bs-2" ]
  [ "$(fleet_for_usage 9000 2800 bs-4 bs-2)" = "bs-4 bs-2" ]
}

@test "rejects non-numeric usage" {
  run fleet_for_usage "12.5" 2800 bs-4 bs-2
  [ "$status" -ne 0 ]
  run fleet_for_usage "" 2800 bs-4 bs-2
  [ "$status" -ne 0 ]
}

@test "rewrites only exact runs-on: ubuntu-latest lines" {
  input='jobs:
  a:
    runs-on: ubuntu-latest
  b:
    runs-on: ubuntu-22.04
  c:
      runs-on:   ubuntu-latest   
  d:
    runs-on: [self-hosted, ubuntu-latest]'
  expected="jobs:
  a:
    runs-on: \${{ vars.CI_RUNNER || 'ubuntu-latest' }}
  b:
    runs-on: ubuntu-22.04
  c:
      runs-on:   \${{ vars.CI_RUNNER || 'ubuntu-latest' }}
  d:
    runs-on: [self-hosted, ubuntu-latest]"
  [ "$(printf '%s\n' "$input" | rewrite_runs_on)" = "$expected" ]
}

@test "the generated workflow runs on the overflow fleet and passes config by env" {
  yaml=$(workflow_yaml acme acme/api,acme/web 2800 bs-4 bs-2)
  [[ "$yaml" == *"runs-on: bs-2"* ]]
  [[ "$yaml" == *"RUNNER_BUDGET_REPOS: acme/api,acme/web"* ]]
  [[ "$yaml" == *'${{ secrets.RUNNER_BUDGET_PAT }}'* ]]
  [[ "$yaml" == *"bash .github/scripts/runner-budget select"* ]]
}
