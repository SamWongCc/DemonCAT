# DemonCAT (dcat)

> **DemonCAT**（简称 **dcat**）— Demon Computing Availability Tools
> Linux 计算故障注入工具：统一的命令面、预检护栏、状态跟踪；具体故障以**外部脚本 + 声明式配置**接入。

> 覆盖 CPU / 内存 / 存储 / 网络 / 文件系统 / 进程 / 容器 / 系统 / NPU 模块。加一个故障 = 加一个脚本 + 配置文件一行，**免重新编译**。

## 依赖说明

极简 Linux 环境（最小安装/容器）可能不自带以下工具。运行 `scripts/install_deps.sh` 一键安装。

### 编译依赖

| 依赖 | 包名 (apt) | 包名 (yum) | 用途 |
|---|---|---|---|
| cmake ≥ 3.10 | `cmake` | `cmake` | 构建系统 |
| C 编译器 | `gcc` | `gcc` | 编译 dcat 二进制 |
| pthread | `libc6-dev` | `glibc-devel` | 状态锁 |
| dlopen | `libc6-dev` | `glibc-devel` | 动态插件加载 |

### 运行时依赖（按模块）

| 模块 | 工具 | 包名 (apt) | 包名 (yum) | 需要 root |
|---|---|---|---|---|
| **CPU** | `perl`, `taskset` | `perl`, `util-linux` | `perl`, `util-linux` | core_offline 需要 |
| **存储** | `dd` | `coreutils` | `coreutils` | — |
| **网络** | `tc`, `ip` | `iproute2` | `iproute` | ✅ |
| | `ethtool` | `ethtool` | `ethtool` | ✅ |
| | `iptables` | `iptables` | `iptables` | ✅ |
| | `systemctl` | `systemd` | `systemd` | ✅ |
| | `python3` | `python3` | `python3` | — |
| **进程** | `kill`, `perl` | `util-linux`, `perl` | `util-linux`, `perl` | 部分需要 |
| **NPU** | `hccn_tool` | — (Atlas 驱动自带) | — | ✅ |

> 无 NPU 硬件的环境可跳过 NPU 模块，不影响其他模块使用。

## 快速开始

```bash
# 1. 一键安装依赖（Debian/Ubuntu/RHEL/CentOS 自动识别）
bash scripts/install_deps.sh

# 2. 编译
cmake -B build && cmake --build build

# 3. 运行测试
ctest --test-dir build --output-on-failure

# 4. 列出故障目录
./build/dcat list

# 5. 注入 CPU 过载（2 核）
./build/dcat inject rCPU_overload --cores=0,1

# 6. 查询故障是否生效
./build/dcat query rCPU_overload --cores=0,1

# 7. 清除故障
./build/dcat clean rCPU_overload --cores=0,1

# 查看帮助
./build/dcat --help
./build/dcat inject --help
./build/dcat inject rCPU_overload --help
```

## 命令格式

```
dcat <subcommand> [uid] [--key=value ...] [--config <path>] [--help]
```

| 子命令 | 说明 | 示例 |
|---|---|---|
| `inject <uid> --p1=v1 ...` | 注入故障，同步阻塞执行 | `dcat inject rCPU_overload --cores=4` |
| `clean <uid> [--k1=v1 ...]` | 按参数匹配清除活跃注入 | `dcat clean rCPU_overload --cores=4` |
| `query [uid] [--k1=v1 ...]` | 无 uid：查全部活跃记录；有 uid：验证故障生效 | `dcat query` / `dcat query rCPU_overload` |
| `list` | 列出故障目录 | `dcat list` |

详细使用手册见 [docs/user_manual.md](docs/user_manual.md)，技术规格见 [SPEC.md](SPEC.md)，架构设计见 [DESIGN.md](DESIGN.md)。

## 当前故障目录（65 条）

### CPU 模块（5 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rCPU_overload` | cores | load_pct(默认100) | CPU核心满载（perl纯用户态） |
| `rCPU_core_offline` | cores | — | CPU 核离线（sysfs） |
| `rCPU_quota` | quota_pct | cg_path | cgroup CPU 配额上限 1-99% |
| `rCPU_freq` | cores,freq_mhz | — | CPU 降频（cpufreq sysfs） |
| `rCPU_core_hang` | cores | — | CPU 核挂死（RT 优先级独占，参数同核离线） |

### 内存模块（4 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rMEM_leak` | size_mb | — | 内存泄漏指定量（持有不释放） |
| `rMEM_oom` | rate_mb | — | 内存不足至 OOM（无上限分配触发 OOM killer） |
| `rMEM_fragment` | blocks | block_kb(默认1024) | 内存碎片化（隔块释放造空洞） |
| `rMEM_swap_overload` | size_mb | — | swap 过载（超空闲 RAM 强制换出） |

### 存储模块（7 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rDISK_write_overload` | device | workers(默认4), size_mb(默认200) | 磁盘写压（dd 多实例） |
| `rDISK_part_full` | path | size | 分区空间满（size 支持 M/G；缺省灌至满） |
| `rDISK_inode_exhaust` | path | count(默认100000) | 分区 inode 耗尽（大量空文件） |
| `rDISK_io_delay` | device,delay_ms | — | 磁盘 IO 延迟（device-mapper delay） |
| `rDISK_io_error` | device | — | 磁盘 IO 错误（device-mapper error） |
| `rDISK_scsi_error` | device | — | SCSI 注错（fail_make_request，需内核 CONFIG） |
| `rDISK_loss` | device | — | 磁盘丢失（device/delete；clean rescan） |

### 网络模块（13 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rNET_delay` | iface, delay_ms | — | 网络延迟（tc netem） |
| `rNET_loss` | iface, loss_pct | — | 网络丢包（tc netem） |
| `rNET_reorder` | iface, reorder_pct | — | 网络乱序（tc netem） |
| `rNET_down` | iface | — | 网卡 down（ip link） |
| `rNET_degrade` | iface | speed_mbps(默认10) | 网卡降速（ethtool） |
| `rNET_port_occupy` | port | protocol(默认tcp) | 端口占用（socket holder） |
| `rNET_service_stop` | service | — | 服务停止（systemctl） |
| `rNET_link_flap` | iface | cycle_sec(默认2), count(默认10) | 链路闪断（ip link 循环） |
| `rNET_bw_limit` | iface, rate_kbps | — | 带宽限制（tc tbf） |
| `rNET_jitter` | iface, delay_ms, jitter_ms | — | 延迟抖动（tc netem） |
| `rNET_tcp_loss` | port | direction(默认both) | TCP 丢包（iptables DROP） |
| `rNET_corrupt` | iface, corrupt_pct | — | 网络错包（tc netem corrupt） |
| `rNET_conn_exhaust` | target | count(默认1000) | 连接耗尽（持有 N 条出向 TCP） |

### 文件系统模块（2 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rFS_file_lock` | path,mode | — | 文件锁（noread/nowrite/norw/nodelete） |
| `rFS_iowait_high` | path | workers(默认4) | iowait 高（定向挂载点，多 worker 小块同步 dd） |

### 进程模块（6 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rPROC_exit` | pid | — | 进程退出（kill -9，不可恢复，inject-only） |
| `rPROC_hang` | pid | — | 进程挂起（SIGSTOP） |
| `rPROC_zstate` | pid | — | 僵尸进程（kill 目标进程 → 僵尸，clean 杀父进程回收，不可恢复） |
| `rPROC_fork_bomb` | count | — | 进程数过多（受控 fork 炸弹） |
| `rPROC_loop` | threads | — | 进程/线程死循环 |
| `rPROC_fd_exhaust` | count | — | 进程句柄耗尽（单进程 open 至 RLIMIT_NOFILE） |

### 容器模块（2 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rDOCKER_kill` | container | — | 杀容器实例（docker kill；clean docker start） |
| `rDOCKER_mem_overload` | container,size | — | 容器内存过载（size 支持 M/G） |

### 系统模块（2 条，inject-only）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rSYS_panic` | — | — | 系统 panic（sysrq 'c'，不可恢复） |
| `rSYS_poweroff` | mode | — | 机器下电/重启（mode=0 重启，1 下电，inject-only） |

### NPU 模块（24 条）

| UID | 必填 | 可选 | 说明 |
|---|---|---|---|
| `rNPU_link_down` | chip | — | RoCE 链路 down（-cfg recovery） |
| `rNPU_ip_change` | chip, address, netmask | — | RoCE IP 变更（sidecar 回放） |
| `rNPU_gw_change` | chip, gateway | — | RoCE 网关变更（sidecar 回放） |
| `rNPU_netdetect_change` | chip, address | — | Netdetect IP 变更（sidecar 回放） |
| `rNPU_arp_poison` | chip, dev, ip, mac | — | ARP 毒化（add wrong mac） |
| `rNPU_arp_del` | chip, dev, ip | — | ARP 条目删除（sidecar 回放） |
| `rNPU_route_add` | chip, address, netmask, gateway | — | 添加 RoCE 路由（del 清理） |
| `rNPU_route_del` | chip, address, netmask | — | 删除 RoCE 路由（sidecar 回放） |
| `rNPU_route_clear` | chip | — | 清空路由表（-cfg recovery） |
| `rNPU_iprule_add` | chip, dir, ip, table | — | 添加 ip rule（del 清理） |
| `rNPU_iprule_del` | chip, dir, ip | — | 删除 ip rule（sidecar 回放） |
| `rNPU_iproute_add` | chip, ip, ip_mask, via, dev, table | — | 添加 ip route（del 清理） |
| `rNPU_iproute_del` | chip, ip, ip_mask, table | — | 删除 ip route（sidecar 回放） |
| `rNPU_bw_limit` | chip, bw_limit | — | RoCE 带宽限速（设回 max） |
| `rNPU_mtu_mismatch` | chip, size | — | RoCE MTU 变更（sidecar 回放） |
| `rNPU_fec_change` | chip, encoding | — | RoCE FEC 编码变更（sidecar 回放） |
| `rNPU_dscp_tc_change` | chip, dscp, tc | — | DSCP→TC 映射变更（sidecar 回放） |
| `rNPU_prio_tc_change` | chip, map | — | Prio→TC 映射变更（sidecar 回放） |
| `rNPU_pfc_change` | chip, bitmap | — | PFC 位图变更（sidecar 回放） |
| `rNPU_roce_port_change` | chip, port | — | RoCE UDP 端口变更（sidecar 回放） |
| `rNPU_freq_down` | chip,freq | bmc_ip,bmc_user,bmc_pass | NPU 降频（hccn_tool；ipmitool 兜底） |
| `rNPU_aic_fault` | chip | — | NPU AI 核(aic) 故障（未在真实环境测试） |
| `rNPU_aiv_fault` | chip | — | NPU AI 向量核(aiv) 故障（未在真实环境测试） |
| `rNPU_hbm_fault` | chip | — | NPU HBM 故障（未在真实环境测试） |

## 退出码

| 码 | 含义 |
|---|---|
| 0 | 成功 |
| 1 | 运行错误（脚本失败等） |
| 2 | 解析错误（命令格式不合法） |
| 3 | 预检拒绝（参数缺失/不合法/op 不支持） |
| 4 | 未找到（uid 不在目录中） |

## 技术栈

- C11（ISO/IEC 9899:2011），CMake 构建
- cJSON（vendored 单文件库）
- pthread（状态锁）
- INI 配置文件（`demoncat.conf`）
- 输出格式：JSON
