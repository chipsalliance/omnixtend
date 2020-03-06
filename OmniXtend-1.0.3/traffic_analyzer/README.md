## Live capture OmniXtend frame with Wireshark

Assuming OmniXtend's  Ether type is 0xAAAA

```
sudo wireshark -X lua_script:omnixtend.lua -i <interface> -f "ether proto 0xAAAA"
```
Then, click "Start Capturing packets" in Wireshark

## Parse OmniXtend from cap file

```
wireshark -X lua_script:omnixtend.lua -r <cap-file>
```

For instance:
```
wireshark -X lua_script:omnixtend.lua -r ./OmniXtend202010.cap

```
