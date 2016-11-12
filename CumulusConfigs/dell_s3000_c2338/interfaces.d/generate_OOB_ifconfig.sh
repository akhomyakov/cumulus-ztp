# This script is not used in ZTP process. Its sole purpose is to quickly generate files for access interface configs in this folder.
main_vlan=549
# Port 45 is reserved for management of TOR1 switch
tor1_vlan=553
# Port 46 is reserved for management of TOR2 switch
tor2_vlan=554
# Port 47 is reserved for management of PDU A
pduA_vlan=544
# Port 48 is reserved for management of PDU B
pduB_vlan=545
# Main access ports
for port in {1..44}
do
  echo "auto swp"$port > "swp$port.intf"
  echo "iface swp"$port >> "swp$port.intf"
  echo "   mtu 9000" >> "swp$port.intf"
  echo "   bridge-access $main_vlan" >> "swp$port.intf"
done

# TOR1 managmenet port
echo "auto swp45" > swp45.intf
echo "iface swp45" >> swp45.intf
echo "   mtu 9000" >> swp45.intf
echo "   bridge-access $tor1_vlan" >> swp45.intf

# TOR2 management port
echo "auto swp46" > swp46.intf
echo "iface swp46" >> swp46.intf
echo "   mtu 9000" >> swp46.intf
echo "   bridge-access $tor2_vlan" >> swp46.intf

# PDU A (power)
echo "auto swp47" > swp47.intf
echo "iface swp47" >> swp47.intf
echo "   mtu 9000" >> swp47.intf
echo "   bridge-access $pduA_vlan" >> swp47.intf

# PDU B (power)
echo "auto swp48" > swp48.intf
echo "iface swp48" >> swp48.intf
echo "   mtu 9000" >> swp48.intf
echo "   bridge-access $pduB_vlan" >> swp48.intf
