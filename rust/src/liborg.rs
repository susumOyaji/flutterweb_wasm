use wasm_bindgen::prelude::*;
use web_sys::{Request, RequestInit, RequestMode, Response};
use scraper::{Html, Selector};
use serde::{Serialize};
use wasm_bindgen_futures::JsFuture;
use js_sys::{Array, Reflect};
use serde_wasm_bindgen::to_value;
use std::collections::HashMap;
use std::error::Error;
use reqwest;

use reqwest::Client;
use wasm_bindgen_futures::spawn_local;
use serde_json::Value;


#[wasm_bindgen]
pub fn greet(name: &str) -> String {
    format!("Hello, {}!", name)
}

#[wasm_bindgen]
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}


/*
#[wasm_bindgen]     
pub async fn fetch_data_rust(stock_codes: String) -> Result<JsValue, JsValue> {
    // 仮のデータ取得処理（本来は API 呼び出しなどを行う）
    let data = format!(r#"{{"codes": {}}}"#, stock_codes);

    // JSON 形式で JavaScript に渡す
    Ok(JsValue::from_str(&data))
}
*/

// `fetch` を呼び出す関数
#[wasm_bindgen]
pub async fn js_fetch(url: String) -> Result<JsValue, JsValue> {
    let opts = RequestInit::new();
    opts.set_method("GET");  // 修正済み
    opts.set_mode(RequestMode::Cors);  // 修正済み

    let request = Request::new_with_str_and_init(&url, &opts)?;
    let window = web_sys::window().ok_or("No global `window` exists")?;
    let response = JsFuture::from(window.fetch_with_request(&request)).await?;
    let response: Response = response.dyn_into()?;

    let text = JsFuture::from(response.text()?).await?;
    Ok(text)
}

/*
#[wasm_bindgen]
pub async fn fetch_data_rust(codes_json: String) -> Result<JsValue, JsValue> {
    Ok(JsValue::from_str("{\"message\": \"Hello from Rust\"}"))
}



*/

/*
#[wasm_bindgen]
pub async fn fetch_data_rust(codes_json: String) -> Result<JsValue, JsValue> {
    match fetch_data(codes_json).await {
        Ok(results) => {
            // Rustのデータ構造をJSON文字列にシリアライズ
            let json_string = serde_json::to_string(&results).map_err(|e| e.to_string())?;
            // JSON文字列をJavaScriptの文字列として返す
            Ok(JsValue::from_str(&json_string))
        }
        Err(e) => Err(JsValue::from_str(&e.to_string())),
    }
}




*/




#[wasm_bindgen]
pub async fn fetch_data_rust(codes_json: String) -> Result<JsValue, JsValue> {
    let url = "https://finance.yahoo.co.jp/quote/%5EDJI"; // 例: ダウ平均株価

    let client = Client::new();

    let res = client.get(url)
        .send()
        .await
        .map_err(|e| JsValue::from_str(&format!("HTTPリクエスト失敗: {}", e)))?;

    let json: Value = res.json()
        .await
        .map_err(|e| JsValue::from_str(&format!("JSON解析失敗: {}", e)))?;

    Ok(to_value(&json).unwrap())
}




/*
#[wasm_bindgen]
pub async fn fetch_data_rust(codes_json: String) -> Result<JsValue, JsValue> {
    println!("fetch_data_bridge: {:?}", codes_json);
    
    match fetch_data(codes_json).await {
        Ok(results) => {
            // 結果の表示
            for result in results.iter() {
                println!("{:?}", result);
            }
            // ✅ Rustの Vec<T> を JsValue に変換
            to_value(&results).map_err(|e| JsValue::from_str(&e.to_string()))
        }
        Err(e) => Err(JsValue::from_str(&e.to_string())), // ✅ `String` を `JsValue` に変換
    }
}

*/




async fn fetch_data(codes_json: String) -> Result<Vec<HashMap<String, String>>, Box<dyn Error>> {
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
        let res = reqwest::get(url).await?.text().await?;
        let document = Html::parse_document(&res);
        println!("document: {:?}", document);

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
            let price_change_selector = Selector::parse(extra_selector_str).unwrap();
            if let Some(price_change_element) = document.select(&price_change_selector).next() {
                let nested_span_selector = Selector::parse("span").unwrap();
                if let Some(plus_element) = price_change_element.select(&nested_span_selector).next() {
                    let plus_text = plus_element.inner_html();
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
            let res = reqwest::get(&url).await?.text().await?;
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

            let spanements_list: Vec<String> = prices.split(", ").map(|s| s.to_string()).collect();

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

