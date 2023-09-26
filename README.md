# PPP for X68000Z and Raspberry Pi

この覚書は、X68000ZをUARTクロスでRaspbery Piと接続し、PPPを利用してTCP/IPネットワークを使えるようにするためのメモです。

---

## 必要なもの

* X68000Z (ファームウェア1.3.1以降)
* X68000Z用UARTケーブル
* X68000Z用USBメモリ
* Raspberry Pi (3A+/3B+/4B/Zero2W でのみ確認しています)
* Raspberry Pi用新規microSDカード

---

## Raspberry Pi の準備

Raspberry Pi Imager を使って、最新の Raspberry Pi OS (32bit) Lite を書き込みます。
歯車マークを押して、SSHを有効にし、Wi-Fiの設定もここで行ってしまいましょう。

<img src='images/raspios.png'/>

---

### PPPソフトウェアダウンロード

Human68k版移植開発者の白倉さんのサイトからダウンロードできます。

* [X680x0のインターネット関係ツールのページ](https://argrath.ub32.org/x680x0/internet.html)

### 参考情報

パピコニアンさんのサイトが大変参考になります。(この覚書とは細部は少し異なりますがおおよそやることは同じです)

* [X68000とRaspberry Piをシリアル接続してX68000にネット環境を構築する](http://retropc.net/mm/x68k/rasp-x/)


### ネットワーク構成

* DNS(Wi-FiルータLAN側アドレス) ... 192.168.11.1
* デフォルトゲートウェイ(Wi-FiルータLAN側アドレス) ... 192.168.11.1
* サブネット(WLAN) ... 192.168.11.0/255.255.255.0
* サブネット(PPP) ... 192.168.31.0/255.255.255.0
* Raspberry Pi IPアドレス(WLAN) ... 192.168.11.x (DHCP自動取得)
* Raspberry Pi IPアドレス(PPP) ... 192.168.31.101
* X680x0 PPP IPアドレス ... 192.168.31.68

### Raspberry Pi設定 (IPルーティングの有効化 と IPv6の無効化)

設定3で既に実施している場合は不要

        sudo vi /etc/sysctl.conf

コメントアウトされている行を有効化

        net.ipv4.ip_forward=1 

以下の行を追加

        net.ipv6.conf.all.disable_ipv6=1 

再起動

        sudo reboot

ipv6の行が出力されないことを確認

        ifconfig

### Raspberry Pi設定 (iptables)

設定3で既に実施している場合は不要

        sudo apt install iptables-persistent
        sudo iptables –-table nat –-append POSTROUTING --out-interface wlan0 -j MASQUERADE
        sudo iptables -t nat -L -v -n
        sudo netfilter-persistent save

もし上記設定だけだとルーティングされない場合は以下追加

        sudo iptables –-append FORWARD –-in-interface ppp0 -j ACCEPT

### Raspberry Pi PPPサーバの起動

既にインストールされているはずだけど念の為

        sudo apt install ppp

pppd.sh を以下の内容で作成する

        /usr/sbin/pppd /dev/ttyUSB0 38400 local 192.168.31.101:192.168.31.68 noipv6 proxyarp local noauth debug nodetach dump nocrtscts passive persist maxfail 0 holdoff 1 noauth

pppd.sh 起動

        nohup sudo ./pppd.sh > log-pppd &

68を再起動して接続できることを確認する。


### X680x0側設定 (CONFIG.SYS)

etherL12.sys の代わりに ppp.sys を組み込む。

        FILES     = 50
        BUFFERS   = 99 4096
        LASTDRIVE = Z:
        PROCESS   = 32 10 50
        DEVICE    = \USR\SYS\ppp.sys

### X680x0側設定 (\etc\hosts)

設定3とは異なるので注意

        127.0.0.1       localhost   localhost.local
        192.168.31.68   x68030      x68030.local
        192.168.31.101  raspi2       raspi2.local

### X680x0側設定 (\etc\network)

設定3とは異なるので注意

        127   loopback
        192.168.31  private-net

### X680x0側設定 (\etc\linkup.ppp)

デフォルトのまま

        MYADDR:
          keep

### X680x0側設定 (\etc\conf.ppp)

以下追記する

    raspi:
      set debug phase
      disable vjcomp
      deny vjcomp
      disable lqr
      deny lqr
      disable pred1
      deny pred1
      disable chap
      disable pap
      deny chap
      deny pap
      set openmode active
      set speed 9600
      set ifaddr 192.168.31.68 192.168.31.101
      dial

### X680x0側設定 (AUTOEXEC.BAT)

設定3とは異なるので注意

        SET SYSROOT=C:\
        SET PPP=C:\ETC
        SET PPPLOG=C:\TEMP\PPP.LOG
        SET HOST=x68030
        tmsio
        xip -n2
        ppp raspi
        inetdconf +dns 192.168.11.1 +router 192.168.31.1