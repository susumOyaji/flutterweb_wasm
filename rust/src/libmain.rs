use reqwest;
use serde_json;
use scraper::{Html, Selector};
use std::error::Error;
use std::collections::HashMap;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn greet(name: String) -> String {
    format!("Hello, {}!", name)
}

// Macro to use the console log more easily
macro_rules! console_log {
    ($($t:tt)*) => (log(&format_args!($($t)*).to_string()))
}

#[wasm_bindgen]
pub async fn fetch_data_rust(codes_json: String) -> Result<JsValue, JsValue> {
    console_log!("fetch_data_bridge: {:?}", codes_json);
    match fetch_data(codes_json).await {
        Ok(results) => {
            console_log!("Results: {:?}", results);
            match serde_wasm_bindgen::to_value(&results) {
                Ok(val) => Ok(val),
                Err(e) => Err(JsValue::from_str(&format!("Error serializing results: {}", e))),
            }
        }
        Err(e) => Err(JsValue::from_str(&format!("Error fetching data: {}", e))),
    }
}

async fn fetch_data(codes_json: String) -> Result<Vec<HashMap<String, String>>, Box<dyn Error>> {
    let mut data_list = Vec::new();
    let stock_codes: Vec<String> = serde_json::from_str(&codes_json)?;

    let url_selector_map = vec![
        (
            "https://finance.yahoo.co.jp/quote/%5EDJI",
            vec![
                "span._PriceBoardMain__code_1wkkf_75",
                "h2._PriceBoardMain__name_1wkkf_32",
                "span._StyledNumber__value_x0ii7_10",
            ],
            "Dow".to_string(),
            "Dow Stock Data".to_string(),
        ),
        (
            "https://finance.yahoo.co.jp/quote/998407.O",
            vec![
                "span.code__1yLy",
                "h2.name__xcPE",
                "span.number__3wVT",
                ".priceChange__36Ms",
            ],
            "Nikkei".to_string(),
            "Nikkei Stock Data".to_string(),
        ),
        (
            "https://finance.yahoo.co.jp/quote/USDJPY=FX",
            vec![
                "._PriceBoardMenu__label_a6bng_17",
                "h2._FxPriceBoardMain__name_qgu28_20",
                "._FxPriceBoardMain__price_qgu28_61",
            ],
            "Fx".to_string(),
            "Fx Rate Data".to_string(),
        ),
    ];

    let anyurl_selector_map = vec![
        (
            "https://finance.yahoo.co.jp/quote/{}.T",
            vec![
                "span.PriceBoardMain__code__2wso",
                "h2.PriceBoardMain__name__6uDh",
                "span.StyledNumber__value__3rXW",
            ],
            "Any".to_string(),
            "Any Stock Data".to_string(),
        ),
    ];

    for (url, selectors, title, description) in url_selector_map {
        match reqwest::get(url).await {
            Ok(res) => match res.text().await {
                Ok(body) => {
                    let document = Html::parse_document(&body);
                    let mut result = HashMap::new();
                    result.insert("Title".to_string(), title.clone());
                    result.insert("Description".to_string(), description.clone());

                    let code_selector = Selector::parse(selectors[0]).unwrap();
                    let code = document
                        .select(&code_selector)
                        .next()
                        .map_or("Code not found".to_string(), |e| e.inner_html());
                    result.insert("Code".to_string(), code);

                    let name_selector = Selector::parse(selectors[1]).unwrap();
                    let name = document
                        .select(&name_selector)
                        .next()
                        .map_or("Name not found".to_string(), |e| e.inner_html());
                    result.insert("Name".to_string(), name);

                    let price_selector = Selector::parse(selectors[2]).unwrap();
                    let spanements_list: Vec<String> = document
                        .select(&price_selector)
                        .take(3)
                        .map(|e| e.inner_html())
                        .collect();

                    for (i, value) in spanements_list.iter().enumerate() {
                        let key = match i {
                            0 => "Price",
                            1 => "Ratio",
                            2 => "Percent",
                            _ => continue,
                        };
                        result.insert(key.to_string(), value.clone());
                    }

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
                Err(e) => eprintln!("Error getting text from response for {}: {}", url, e),
            },
            Err(e) => eprintln!("Error fetching {}: {}", url, e),
        }
    }

    if let Some((url_template, selectors, title, description)) = anyurl_selector_map.first() {
        for stock_code in stock_codes {
            let url = url_template.replace("{}", &stock_code);
            match reqwest::get(&url).await {
                Ok(res) => match res.text().await {
                    Ok(body) => {
                        let document = Html::parse_document(&body);
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
                                _ => continue,
                            };
                            result.insert(key.to_string(), value.clone());
                        }
                        data_list.push(result);
                    }
                    Err(e) => eprintln!("Error getting text from response for {}: {}", url, e),
                },
                Err(e) => eprintln!("Error fetching {}: {}", url, e),
            }
        }
    }

    Ok(data_list)
}

// Helper function for logging to the browser console
#[wasm_bindgen]
extern {
    #[wasm_bindgen(js_namespace = console)]
    fn log(s: &str);
}

