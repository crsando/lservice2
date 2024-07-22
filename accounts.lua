return {
    md = {
        ["sim"] = { front_addr =  'tcp://121.37.80.177:20004', broker = "7090", user = "7572" },
        ["openctp"] = { front_addr =  'tcp://121.37.80.177:20004', broker = "7090", user = "7572" },
        ["gtja-1"] = { front_addr =  "tcp://180.169.75.18:61213", broker = "7090", user = "85194065" },
        ["gtja-2"] = { front_addr =  "tcp://180.169.75.18:61213", broker = "7090", user = "85194065" },
        ["gtja"] = { front_addr =  "tcp://180.169.75.18:61213", broker = "7090", user = "85194065" },
    },
    trader = {
        ["openctp-7x24"] = {
            front_addr = "tcp://121.37.80.177:20002", 
            broker = "7090", 
            user = "7572", 
            pass = "123456", 
            app_id = "client_tara_060315", 
            auth_code = "20221011TARA000",
        },
        ["openctp"] = {
            front_addr = "tcp://121.37.90.193:20002", 
            broker = "7090", 
            user = "7572", 
            pass = "123456", 
            app_id = "client_tara_060315", 
            auth_code = "20221011TARA000",
        },
        ["gtja-1"] = {
            front_addr = "tcp://180.169.75.18:61205",
            broker = "7090", 
            user = "85194065", 
            pass = "bE19930706", 
            app_id = "client_tara_060315", 
            auth_code = '20221011TARA0001',
        },
        -- ctpc.ctp_trader_init(nil, "tcp://180.169.75.18:61205", "7090", "85204055", "zhy19930311", "client_tara_231031", "20230907ZHOUYH01")
        ["gtja-2"] = {
            front_addr = "tcp://180.169.75.18:61205",
            broker = "7090", 
            user = "85204055", 
            pass = "zhy19930311", 
            app_id = "client_tara_231031", 
            auth_code = '20230907ZHOUYH01',
        },
    }
}