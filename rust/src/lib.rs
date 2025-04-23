use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::future_to_promise;
use js_sys::Promise;
use reqwest;
use scraper::{Html, Selector};
use serde::{Deserialize, Serialize};
use serde_json::json;

#[derive(Serialize, Deserialize, Debug)]
struct StockData {
    code: String,
    name: String,
    price: String,
    ratio: String,
    percent: String,
    // Add other fields you want to scrape
}

#[wasm_bindgen]
pub fn fetch_data_rust(codes_json: String) -> Promise {
    let future = async move {
        match fetch_and_scrape_multiple(&codes_json).await {
            Ok(data) => Ok(JsValue::from_str(&data)),
            Err(e) => Err(JsValue::from_str(&format!("Error: {}", e))),
        }
    };
    future_to_promise(future)
}

async fn fetch_and_scrape_multiple(codes_json: &str) -> Result<String, Box<dyn std::error::Error>> {
    let mut stock_codes: Vec<String> = serde_json::from_str(codes_json)?;
    stock_codes.insert(0,"%5EDJI".to_string());
    stock_codes.insert(1,"998407.O".to_string()); // ★ 日経平均のコードを追加
    let mut all_stock_data: Vec<StockData> = Vec::new();

    for code in stock_codes {
        match code.as_str() {
            "%5EDJI" => {
                match fetch_and_scrape_dow().await {
                    Ok(dow_info) => all_stock_data.push(dow_info),
                    Err(e) => eprintln!("Error fetching data for Dow: {}", e),
                }
            }
            "998407.O" => {
                match fetch_and_scrape_nikkei().await {
                    Ok(nikkei_info) => all_stock_data.push(nikkei_info),
                    Err(e) => eprintln!("Error fetching data for Nikkei: {}", e),
                }
            }
            _ => {
                let url = format!("https://finance.yahoo.co.jp/quote/{}.T", code);
                match fetch_and_scrape_stock(&url).await {
                    Ok(stock_info) => all_stock_data.push(stock_info),
                    Err(e) => eprintln!("Error fetching data for {}: {}", code, e),
                }
            }
        }
    }

    let scraped_data = json!(all_stock_data);
    Ok(scraped_data.to_string())
}

async fn fetch_and_scrape_stock(url: &str) -> Result<StockData, Box<dyn std::error::Error>> {
    let response = reqwest::get(url).await?;
    let body = response.text().await?;
    let document = Html::parse_document(&body);

    let code_selector = Selector::parse("span.PriceBoardMain__code__2wso").unwrap();
    let name_selector = Selector::parse("h2.PriceBoardMain__name__6uDh").unwrap();
    let price_selector = Selector::parse("span.StyledNumber__value__3rXW").unwrap();
    let ratio_selector = Selector::parse("span.PriceChangeLabel__primary__Y_ut > span.StyledNumber__value__3rXW").unwrap();
    let percent_selector = Selector::parse("span.StyledNumber__item--secondary__RTJc > span.StyledNumber__value__3rXW").unwrap();
  
    let code = document.select(&code_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let name = document.select(&name_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let price = document.select(&price_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let ratio = document.select(&ratio_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let percent = document.select(&percent_selector).next().map(|n| n.inner_html()).unwrap_or_default();

    Ok(StockData {
        code,
        name,
        price,
        ratio,
        percent,
    })
}

async fn fetch_and_scrape_dow() -> Result<StockData, Box<dyn std::error::Error>> {
    let url = "https://finance.yahoo.co.jp/quote/%5EDJI"; // NYダウ平均のURL
    let response = reqwest::get(url).await?;
    let body = response.text().await?;
    let document = Html::parse_document(&body);


    let code_selector = Selector::parse("span._PriceBoardMain__code_feslz_14").unwrap();
    let name_selector = Selector::parse("h2._PriceBoardMain__name_feslz_139").unwrap();
    let price_selector = Selector::parse("span._StyledNumber__value_x0ii7_10").unwrap();
    let ratio_selector = Selector::parse("span._PriceChangeLabel__primary_l4zfe_55 > span._StyledNumber__value_x0ii7_10").unwrap();
    let percent_selector = Selector::parse("span._PriceChangeLabel__secondary_l4zfe_61 > span._StyledNumber__value_x0ii7_10").unwrap();

    

    let code = document.select(&code_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let name = document.select(&name_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let price = document.select(&price_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let ratio = document.select(&ratio_selector).next().map(|n| n.inner_html()).unwrap_or_default(); // 正しいSelectorに修正してください
    let percent = document.select(&percent_selector).next().map(|n| n.inner_html()).unwrap_or_default(); // 正しいSelectorに修正してください
    
    Ok(StockData {
        code,
        name,
        price,
        ratio,
        percent,
    })
}

async fn fetch_and_scrape_nikkei() -> Result<StockData, Box<dyn std::error::Error>> {
    let url = "https://finance.yahoo.co.jp/quote/998407.O"; // 日経平均のURL
    let response = reqwest::get(url).await?;
    let body = response.text().await?;
    let document = Html::parse_document(&body);

    // ★ 日経平均専用の Selector を定義
    let code_selector = Selector::parse("span.code__1yLy").unwrap(); // 共通の可能性あり
    let name_selector = Selector::parse("h2.name__xcPE").unwrap();
    let price_selector = Selector::parse("span.number__3wVT").unwrap();

    let ratiosign_selector = Selector::parse("span.priceChange__36Ms > span:first-child").unwrap();
    let ratio_selector = Selector::parse("span.priceChange__36Ms > span.number__3wVT").unwrap();

    let percent_selector = Selector::parse("span.changePriceRate__3pJv > span.priceChange__36Ms > span.number__3wVT").unwrap();
   
    let code = document.select(&code_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let name = document.select(&name_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let price = document.select(&price_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let mut ratio = document.select(&ratio_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let ratiosign = document.select(&ratiosign_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    let mut percent = document.select(&percent_selector).next().map(|n| n.inner_html()).unwrap_or_default();
    
    ratio = ratiosign.clone() + &ratio;
    percent = ratiosign + &percent;

    Ok(StockData {
        code,
        name,
        price,
        ratio,
        percent,
    })
}