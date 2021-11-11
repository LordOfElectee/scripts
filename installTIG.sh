#!/bin/bash
function installInfluxDB {
    echo -e '\n\e[32mПодготовка к установке InfluxDB\e[0m\n' && sleep 1
	  sudo apt install software-properties-common
    apt update && apt upgrade -y
    wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb && dpkg -i influxdb_1.8.10_amd64.deb
    systemctl start influxdb
    systemctl enable influxdb
}

function installTelegraf {
	  echo -e '\n\e[32mПодготовка к установке Telegraf\e[0m\n' && sleep 1
    wget https://dl.influxdata.com/telegraf/releases/telegraf_1.20.3-1_amd64.deb && dpkg -i telegraf_1.20.3-1_amd64.deb 
    systemctl start telegraf
    systemctl enable telegraf
}

function installGrafana {
	  echo -e '\n\e[32mПодготовка к установке Grafana\e[0m\n' && sleep 1
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo apt-add-repository "deb https://packages.grafana.com/enterprise/deb stable main"
    sudo apt update
    sudo apt install grafana
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
}

function createDatabase {
	  influx -execute 'CREATE DATABASE telegraf'
    influx -execute 'CREATE USER admin WITH PASSWORD "$pass" WITH ALL PRIVILEGES'
    influx -execute 'CREATE USER telegraf WITH PASSWORD "$pass"'
    influx -execute 'CREATE USER grafana WITH PASSWORD "$pass"'
    influx -execute 'GRANT WRITE ON "telegraf" TO "telegraf"'
    influx -execute 'GRANT READ ON "telegraf" TO "grafana"'
    # sed -i 's|  # auth-enabled = false|  auth-enabled = true|g' /etc/influxdb/influxdb.conf
    # systemctl restart influxdb
    # sed -i 's|  # password = "metricsmetricsmetricsmetrics"|  password = "$pass"|g' /etc/telegraf/telegraf.conf
    # systemctl restart telegraf
}

echo “Введите опцию установки:”
echo "1 - InfluxDB"
echo "2 - Telegraf"
echo "3 - Grafana"
echo "0 - Не устанавливать мониторинг"
echo "можно вводить несколько по возрастанию 12 / 13 / 23 / 123"
read -p "Введите вариант установки: " setup
read -p "Введите пароль: " pass
case $setup in
1) installInfluxDB;;
2) installTelegraf;; 
3) installGrafana;;
12) installInfluxDB
    installTelegraf
    createDatabase;;
13) installInfluxDB
    installGrafana;;
23) installTelegraf
    installGrafana;;
123) installInfluxDB
    installTelegraf
    installGrafana
    createDatabase;;
0) break;;
*) echo "Нет такой опции";;
esac
# apt install mc -y
# apt install ncdu -y
# apt install net-tools -y
# apt update && apt upgrade -y
