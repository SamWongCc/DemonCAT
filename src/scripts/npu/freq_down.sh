#!/bin/sh
# rNPU_freq_down: lower NPU frequency (hccn_tool; fallback ipmitool BMC power-cap).
# inject: set freq via hccn_tool (save original); fallback ipmitool dcmi power-cap
# clean:  restore original freq (hccn_tool) / remove power cap
# query:  read current freq
# NOTE: exact hccn_tool freq subcommand + ipmitool BMC creds need on-hardware confirmation.

. "$(dirname "$0")/_common.sh"
chip=${DCAT_PARAM_CHIP:?missing required param: chip}
freq=${DCAT_PARAM_FREQ:?missing required param: freq}
npu_validate_chip "$chip"
HCCN="hccn_tool -i $chip"
SIDECAR="/tmp/dcat-rNPU_freq_down-$chip.bak"

case "${DCAT_OP:-inject}" in
    inject)
        npu_check_env 2>/dev/null || true
        orig=$($HCCN -t freq -g 2>/dev/null | grep -oE '[0-9]+' | head -1)
        [ -n "$orig" ] && printf '%s\n' "$orig" > "$SIDECAR"
        if $HCCN -t freq -s "$freq" 2>/dev/null; then
            echo "set npu freq=$freq on chip $chip via hccn_tool"
        elif command -v ipmitool >/dev/null 2>&1; then
            # BMC-level power cap throttles the NPU (user-requested ipmitool path)
            # BMC creds from env (BMC_IP/BMC_USER/BMC_PASS) or --config-driven params
            bmc_ip=${DCAT_PARAM_BMC_IP:-${BMC_IP:-}}
            bmc_u=${DCAT_PARAM_BMC_USER:-${BMC_USER:-}}
            bmc_p=${DCAT_PARAM_BMC_PASS:-${BMC_PASS:-}}
            [ -n "$bmc_ip" ] || { echo "ipmitool path needs BMC_IP (param or env)" >&2; exit 1; }
            ipmitool -I lanplus -H "$bmc_ip" -U "$bmc_u" -P "$bmc_p" \
                dcmi power set_limit limit "$freq" 2>/dev/null || { echo "ipmitool power-cap failed" >&2; exit 1; }
            echo "set npu power-cap=$freq on chip $chip via ipmitool (BMC-level)"
        else
            echo "no freq tool available (hccn_tool freq / ipmitool)" >&2; exit 1
        fi
        ;;
    clean)
        if [ -f "$SIDECAR" ]; then
            orig=$(cat "$SIDECAR")
            $HCCN -t freq -s "$orig" 2>/dev/null || true
            rm -f "$SIDECAR"
            echo "restored npu freq on chip $chip (to $orig)"
        else
            echo "no active freq_down" >&2; exit 1
        fi
        ;;
    query)
        $HCCN -t freq -g 2>/dev/null
        [ -f "$SIDECAR" ] && exit 0 || exit 1
        ;;
    *) echo "unknown op: $DCAT_OP" >&2; exit 1;;
esac
