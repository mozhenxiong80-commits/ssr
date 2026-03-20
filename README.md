# SSR Ubuntu 24.04 一键安装

这个仓库放的是一份可审计的本地安装脚本，不是直接执行陌生人的远程脚本。

## SSH 一行安装

建议把 `main` 替换成你自己的固定 commit 或 tag，再执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-ubuntu24.sh)
```

如果你想自定义端口或密码：

```bash
SSR_PORT=8443 SSR_PASSWORD='改成你的强密码' bash <(curl -fsSL https://raw.githubusercontent.com/mozhenxiong80-commits/ssr/main/install-ssr-ubuntu24.sh)
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
```
