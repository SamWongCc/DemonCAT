#!/bin/sh
# rNPU_hbm_fault: inject HBM (high-bandwidth memory) fault on an NPU chip.
# inject: hccn_tool hbm fault injection (subcommand TBD on Atlas hardware)
# clean:  hccn_tool -cfg recovery
# query:  check hbm fault state
# NOTE: exact hccn_tool hbm-injection subcommand needs on-hardware confirmation.

. "$(dirname "$0")/_common.sh"
chip=${DCAT_PARAM_CHIP:?missing required param: chip}
npu_validate_chip "$chip"
HCCN="hccn_tool -i $chip"

case "${DCAT_OP:-inject}" in
    inject)
        npu_check_env
        $HCCN -hbm -s fault 2>/dev/null \
            || $HCCN -t hbm -s fault 2>/dev/null \
            || { echo "hbm fault injection subcommand failed (confirm on hardware)" >&2; exit 1; }
        echo "injected hbm fault on chip $chip"
        ;;
    clean)
        npu_check_env
        $HCCN -cfg recovery 2>/dev/null || { echo "cfg recovery failed" >&2; exit 1; }
        echo "recovered hbm fault on chip $chip"
        ;;
    query)
        npu_check_env
        $HCCN -hbm -g 2>/dev/null || $HCCN -t hbm -g 2>/dev/null
        exit 0
        ;;
    *) echo "unknown op: $DCAT_OP" >&2; exit 1;;
esac
