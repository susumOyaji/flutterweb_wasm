use reqwest;
//use tokio;
use serde_json;
use scraper::{Html, Selector};
use std::error::Error;
use std::collections::HashMap;
use flutter_rust_bridge::frb;



// flutter_rust_bridge 用の属性をインポート
#[flutter_rust_bridge::frb(sync)]
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}




#[frb]
pub async fn fetch_data_bridge(codes_json: String) -> Result<Vec<HashMap<String, String>>, String> {
    println!("fetch_data_bridge: {:?}", codes_json);
    match fetch_data(codes_json).await {
        Ok(results) => {
            // 結果の表示
            for result in results.iter() {
                println!("{:?}", result);
            }
            Ok(results)
        }
        Err(e) => Err(e.to_string()),
    }
}

async fn fetch_data(codes_json: String) -> Result<Vec<HashMap<String, String>>, Box<dyn Error>> {
    //let client = Client::new();
    let mut data_list = Vec::new();

    // JSON をデコードして "Code" のリストに変換
    let stock_codes: Vec<String> = serde_json::from_str(&codes_json)?;

    // URLごとにセレクタをマッピング
    let url_selector_map = vec![
        (
            "https://finance.yahoo.co.jp/quote/%5EDJI", // URL 1 (ダウ)
            vec![
                "span._PriceBoardMain__code_1wkkf_75",      // Code
                "h2._PriceBoardMain__name_1wkkf_32",      // Name
                "span._StyledNumber__value_x0ii7_10",      // Price/Polarity
            ],
            "Dow".to_string(), // Title
            "Dow Stock Data".to_string(), // Description
        ),
        (
            "https://finance.yahoo.co.jp/quote/998407.O", // URL 2 (日経平均)
            vec![
                "span.code__1yLy",  // Code
                "h2.name__xcPE",  // Name
                "span.number__3wVT", // Price/Polarity
                ".priceChange__36Ms",  // Additional data (Optional)
            ],
            "Nikkei".to_string(), // Title
            "Nikkei Stock Data".to_string(), // Description
        ),
        (
            "https://finance.yahoo.co.jp/quote/USDJPY=FX", // URL 3 (FX)
            vec![
                "._PriceBoardMenu__label_a6bng_17",  // Code
                "h2._FxPriceBoardMain__name_qgu28_20",  // Name
                "._FxPriceBoardMain__price_qgu28_61", // Bid
            ],
            "Fx".to_string(), // Title
            "Fx Rate Data".to_string(), // Description
        ),
    ];

    let anyurl_selector_map = vec![
        (
            "https://finance.yahoo.co.jp/quote/{}.T", // URL 4 (Any)
            vec![
                "span.PriceBoardMain__code__2wso",  // Code
                "h2.PriceBoardMain__name__6uDh",  // Name
                "span.StyledNumber__value__3rXW", // Price/Polarity
            ],
            "Any".to_string(), // Title
            "Any Stock Data".to_string(), // Description
        ),
    ];

    // すべてのURLに対して処理
    for (url, selectors, title, description) in url_selector_map {
        //let res = client.get(url).send().await?.text().await?;
        let res = reqwest::get(url).await?.text().await?;
        let document = Html::parse_document(&res);

        let mut result = HashMap::new();
        result.insert("Title".to_string(), title.clone());
        result.insert("Description".to_string(), description.clone());

        let code_selector = Selector::parse(selectors[0]).unwrap();
        let code = if let Some(element) = document.select(&code_selector).next() {
            element.inner_html()
        } else {
            "Code not found".to_string()
        };
        result.insert("Code".to_string(), code);

        let name_selector = Selector::parse(selectors[1]).unwrap();
        let name = if let Some(element) = document.select(&name_selector).next() {
            element.inner_html()
        } else {
            "Name not found".to_string()
        };
        result.insert("Name".to_string(), name);

        let mut spanements_list: Vec<String> = Vec::new();
        let price_selector = Selector::parse(selectors[2]).unwrap();
        for element in document.select(&price_selector).take(3) {
            spanements_list.push(element.inner_html());
        }
        // spanements_list に3つの要素が格納されていることを前提に、個別の変数に格納
        /*
        let price1 = spanements_list.get(0).map(|s| s.clone()).unwrap_or_default();
        let price2 = spanements_list.get(1).map(|s| s.clone()).unwrap_or_default();
        let price3 = spanements_list.get(2).map(|s| s.clone()).unwrap_or_default();

        result.insert("Price".to_string(), price1);
        result.insert("Ratio".to_string(), price2);
        result.insert("Percent".to_string(), price3); 
        */
        

        for (i, value) in spanements_list.iter().enumerate() {
            let key = match i {
                0 => "Price",
                1 => "Ratio",
                2 => "Percent",
                _ => continue, // ワイルドカードパターンでその他の値をスキップ
            };
            result.insert(key.to_string(), value.clone());
        }





        // 追加の処理
        if let Some(extra_selector_str) = selectors.get(3) {
        // クラスインデックスを適切に指定して、セレクタを解析
        let price_change_selector = Selector::parse(extra_selector_str).unwrap();
        println!("Parsed extra_selector: {:?}", price_change_selector);



            let price_change_selector = Selector::parse(extra_selector_str).unwrap();
            if let Some(price_change_element) = document.select(&price_change_selector).next() {
                let nested_span_selector = Selector::parse("span").unwrap();
                if let Some(plus_element) = price_change_element.select(&nested_span_selector).next() {
                    let plus_text = plus_element.inner_html();
                    println!("Found sign: {}", plus_text);
                    // 結合するなどの処理を行う
                    result.insert("PriceChange".to_string(), plus_text);
                }
            }
        }

        data_list.push(result);
    }

    // 任意の株式コードの処理
    if let Some((url_template, selectors, title, description)) = anyurl_selector_map.first() {
        for stock_code in stock_codes {
            let url = url_template.replace("{}", &stock_code);
            //let res = client.get(&url).send().await?.text().await?;
            let res = reqwest::get(url).await?.text().await?;
            let document = Html::parse_document(&res);

            let mut result = HashMap::new();
            result.insert("Title".to_string(), title.clone());
            result.insert("Description".to_string(), description.clone());

            let code_selector = Selector::parse(selectors[0]).unwrap();
            let stock_code = document
                .select(&code_selector)
                .next()
                .map_or("Code not found".to_string(), |e| e.inner_html());
            result.insert("Code".to_string(), stock_code);

            let name_selector = Selector::parse(selectors[1]).unwrap();
            let stock_name = document
                .select(&name_selector)
                .next()
                .map_or("Name not found".to_string(), |e| e.inner_html());
            result.insert("Name".to_string(), stock_name);

            let price_selector = Selector::parse(selectors[2]).unwrap();
            let prices = document
                .select(&price_selector)
                .take(3)
                .map(|e| e.inner_html())
                .collect::<Vec<String>>()
                .join(", ");



            /*
             // "prices" をカンマで分割し、3つの要素に分ける
            let split_prices: Vec<&str> = prices.split(", ").collect();

            let price = split_prices.get(0).unwrap_or(&"").to_string();
            let tatio = split_prices.get(1).unwrap_or(&"").to_string();
            let percent = split_prices.get(2).unwrap_or(&"").to_string();

            result.insert("Price".to_string(), price);
            result.insert("Ratio".to_string(), tatio);
            result.insert("Percent".to_string(), percent);   
            
            
            */    
            
            

            // "prices" をカンマで分割して Vec<String> に格納
            let spanements_list: Vec<String> = prices.split(", ").map(|s| s.to_string()).collect();

            // インデックスに応じてキーを決定し、`result` に挿入
            for (i, value) in spanements_list.iter().enumerate() {
                let key = match i {
                    0 => "Price",
                    1 => "Ratio",
                    2 => "Percent",
                    _ => continue, // それ以外のインデックスはスキップ
                };
                result.insert(key.to_string(), value.clone());
            }
            
            data_list.push(result);
        }
    }

    Ok(data_list)
}


/*
#[tokio::main]
async fn main() -> Result<(), Box<dyn Error>> {
    // Yahoo!のホームページからHTMLを取得
    let response = reqwest::get("https://finance.yahoo.co.jp/quote/6758.T").await?.text().await?;

    // HTMLをパース
    let document = Html::parse_document(&response);
   
    // 全てのHTMLを表示する場合 
    //println!("{:?}", document.tree);

    // 特定の要素を選択するためのセレクタを作成
    //let selector = Selector::parse("title").unwrap();
    let selector = Selector::parse("span.StyledNumber__value__3rXW").unwrap();

    // 要素を取得して表示
    for element in document.select(&selector) {
        //println!("{}", element.inner_html());
    }
    
    // fetch_data_bridgeを非同期で呼び出す 
    let stock_codes = vec!["6758"];
    let codes_json = serde_json::to_string(&stock_codes).unwrap();
    println!("codes_json: {:?}", codes_json);


    match fetch_data_bridge(codes_json).await {
        Ok(results) => {
            for result in results.iter() {
                println!("{:?}", result);
            }
        }
        Err(e) => eprintln!("Error: {}", e),
    }

   

    Ok(())
}




*/
