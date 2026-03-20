# SSR 一键安装

当前主版本以 `Ubuntu 20.04 LTS` 为准，我已经在你的 `23.27.12.182` 新机器上实机验证通过：`SSR` 正常运行，`BBR` 已启用。

这个仓库放的是一份可审计的本地安装脚本，不是直接执行陌生人的远程脚本。当前合成脚本会自动识别 `apt-get / yum / dnf`，适用于 `Ubuntu 24.04` 和大多数 `CentOS / Rocky / AlmaLinux` 环境；在 `CentOS 7` 上会自动修复到 `vault` 源，并优先使用系统自带 `python2.7`。

## SSH 一行安装

如果你想一条命令同时装 `SSR + BBR`，以后默认执行这个：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-bbr.sh)
```

如果你想随机端口：

```bash
SSR_PORT=random bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-bbr.sh)
```

当前主推环境：

- `Ubuntu 20.04 LTS`: 已实机验证，`SSR + BBR` 都可用
- `Ubuntu 24.04`: 兼容
- `CentOS 7`: `SSR` 可装，`BBR` 取决于内核；老内核会自动跳过

安装完成后，主脚本会额外输出两种可复制链接：

- `ssr://...`
- `shadowrocket://add/...`

建议把 `main` 替换成你自己的固定 commit 或 tag，再执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-ubuntu24.sh)
```

如果你想自定义端口或密码：

```bash
SSR_PORT=8443 SSR_PASSWORD='改成你的强密码' bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-ubuntu24.sh)
```

## BBR 加速

原生 `BBR` 是最稳的一种做法，不装第三方魔改内核，只启用系统已有的 `tcp_bbr + fq`。

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-bbr-ubuntu24.sh)
```

如果你打算一次装完，按这个顺序执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-ubuntu24.sh)
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-bbr-ubuntu24.sh)
```

## Shadowrocket

安装完成后，脚本会输出两种信息：

- 手动填写所需的 `host / port / password / method / protocol / obfs`
- 一条可直接导入的小火箭 `ssr://` 链接

## 默认参数

- port: `443`
- method: `aes-128-ctr`
- protocol: `auth_aes128_md5`
- obfs: `tls1.2_ticket_auth_compatible`

## 常用命令

```bash
systemctl status ssr
journalctl -u ssr -f
systemctl restart ssr
sysctl net.ipv4.tcp_congestion_control
```
