#!/bin/sh
# rNPU_aiv_fault: inject AI-vector-core (aiv) fault on an NPU chip.
# inject: hccn_tool aiv fault injection (subcommand TBD on Atlas hardware)
# clean:  hccn_tool -cfg recovery
# query:  check aiv fault state
# NOTE: exact hccn_tool aiv-injection subcommand needs on-hardware confirmation.

. "$(dirname "$0")/_common.sh"
chip=${DCAT_PARAM_CHIP:?missing required param: chip}
npu_validate_chip "$chip"
HCCN="hccn_tool -i $chip"

case "${DCAT_OP:-inject}" in
    inject)
        npu_check_env
        $HCCN -aiv -s fault 2>/dev/null \
            || $HCCN -t aiv -s fault 2>/dev/null \
            || { echo "aiv fault injection subcommand failed (confirm on hardware)" >&2; exit 1; }
        echo "injected aiv fault on chip $chip"
        ;;
    clean)
        npu_check_env
        $HCCN -cfg recovery 2>/dev/null || { echo "cfg recovery failed" >&2; exit 1; }
        echo "recovered aiv fault on chip $chip"
        ;;
    query)
        npu_check_env
        $HCCN -aiv -g 2>/dev/null || $HCCN -t aiv -g 2>/dev/null
        exit 0
        ;;
    *) echo "unknown op: $DCAT_OP" >&2; exit 1;;
esac
