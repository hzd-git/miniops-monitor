#!/usr/bin/env bats

setup() {
  PROJECT_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  MONITOR_SCRIPT="$PROJECT_DIR/src/miniops-monitor.sh"
}

@test "self-test emits a deterministic alert event" {
  run bash "$MONITOR_SCRIPT" --self-test

  [ "$status" -eq 0 ]
  [[ "$output" == *"timestamp="* ]]
  [[ "$output" == *"schema_version=1"* ]]
  [[ "$output" == *"level=ALERT"* ]]
  [[ "$output" == *"event=threshold_exceeded"* ]]
  [[ "$output" == *"resource=demo value=100 threshold=0"* ]]
}

@test "invalid interval returns configuration failure" {
  run bash "$MONITOR_SCRIPT" --interval 1

  [ "$status" -eq 1 ]
  [[ "$output" == *"event=config_invalid"* ]]
  [[ "$output" == *"reason=interval_out_of_range"* ]]
}

@test "duplicate modes return CLI error" {
  run bash "$MONITOR_SCRIPT" --once --loop

  [ "$status" -eq 2 ]
  [[ "$output" == *"CLI_ERROR"* ]]
}
