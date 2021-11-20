#!/bin/bash
function installInfluxDB {
    echo -e '\n\e[32mПодготовка к установке InfluxDB\e[0m\n' && sleep 1
    sudo apt install software-properties-common
    apt update && apt upgrade -y
    wget https://dl.influxdata.com/influxdb/releases/influxdb_1.8.10_amd64.deb && yes | dpkg -i influxdb_1.8.10_amd64.deb
    systemctl start influxdb
    systemctl enable influxdb
    rm influxdb_1.8.10_amd64.deb
}

function installTelegraf {
    echo -e '\n\e[32mПодготовка к установке Telegraf\e[0m\n' && sleep 1
    wget https://dl.influxdata.com/telegraf/releases/telegraf_1.20.3-1_amd64.deb && yes | dpkg -i telegraf_1.20.3-1_amd64.deb
    systemctl start telegraf
    systemctl enable telegraf
    rm telegraf_1.20.3-1_amd64.deb
}

function installGrafana {
    echo -e '\n\e[32mПодготовка к установке Grafana\e[0m\n' && sleep 1
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo apt-add-repository "deb https://packages.grafana.com/enterprise/deb stable main"
    sudo apt update
    sudo apt install grafana -y
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server
}

function createDatabase {
    influx -execute 'CREATE DATABASE telegraf'
    influx -execute "CREATE USER admin WITH PASSWORD '${pass}' WITH ALL PRIVILEGES"
    influx -execute "CREATE USER telegraf WITH PASSWORD '${pass}'"
    influx -execute "CREATE USER grafana WITH PASSWORD '${pass}'"
    influx -execute 'GRANT WRITE ON "telegraf" TO "telegraf"'
    influx -execute 'GRANT READ ON "telegraf" TO "grafana"'
    sed -i 's|  # auth-enabled = false|  auth-enabled = true|g' /etc/influxdb/influxdb.conf
    systemctl restart influxdb
    sed -i 's|  # password = "metricsmetricsmetricsmetrics"|  password = "'$pass'"|g' /etc/telegraf/telegraf.conf
    systemctl restart telegraf
}

function changeTelegrafConfig {
#    sed -i 's|  # [[inputs.net]]|  [[inputs.net]]|g' /etc/telegraf/telegraf.conf
for line in $(ls /sys/class/net)
do
  if [ -z "$line" ]
  then
  break
  fi 
  if [ -z "$text" ]
  then
  text="\"$line\""
  else
  text=$text", \"$line\""
  fi
done

if  [ -z "$line" ]
then
sed -i 's|# [[inputs.net]]|  [[inputs.net]]|g' /etc/telegraf/telegraf.conf
sed -i 's|#   # interfaces = ["eth0"]|      $text|g' /etc/telegraf/telegraf.conf
else
echo -e '\n\e[31mНе обнаружено сетевых устройста по адресу /sys/class/net\e[0m\n' && sleep 1
fi
}

echo “Введите опцию установки:”
echo "1 - InfluxDB"
echo "2 - Telegraf"
echo "3 - Grafana"
echo "0 - Не устанавливать мониторинг"
echo "можно вводить несколько по возрастанию 12 / 13 / 23 / 123"
read -p "Введите вариант установки: " setup
read -p "Введите пароль: " pass
read -p "Устанавливать время + mc + ncdu? (y/n) " base
case $setup in
1) installInfluxDB;;
2) installTelegraf
   changeTelegrafConfig;; 
3) installGrafana;;
12) installInfluxDB
    installTelegraf
    createDatabase
    changeTelegrafConfig;;
13) installInfluxDB
    installGrafana;;
23) installTelegraf
    changeTelegrafConfig
    installGrafana;;
123) installInfluxDB
    installTelegraf
    installGrafana
    changeTelegrafConfig
    createDatabase;;
*) echo "Нет такой опции";;
esac

case $base in
y) apt install mc -y
   apt install ncdu -y
   apt install net-tools -y
   apt update && apt upgrade -y
   timedatectl set-timezone Asia/Yekaterinburg;;
*) echo "Вышли из установки";;
esac
