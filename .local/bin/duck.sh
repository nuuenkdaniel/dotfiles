echo url="https://www.duckdns.org/update?domains=captnuu&token=4e8900ea-0030-46d8-9026-acfe13b71a9f&ip=" | curl -k -o ~/.duckdns/duck.log -K -
notify-send "duckdns updated"
