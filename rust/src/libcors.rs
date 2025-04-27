use axum::{
    extract::Query,
    http::{Method},
    response::IntoResponse,
    routing::get,
    Router,
};
use serde::Deserialize;
use tower_http::cors::{Any, CorsLayer};
use tokio::sync::OnceCell;
use tokio::task::JoinHandle;
use flutter_rust_bridge::frb;
use js_sys::Promise;
use wasm_bindgen::prelude::*;

static SERVER_HANDLE: OnceCell<JoinHandle<()>> = OnceCell::const_new();

pub async fn start_server() -> JoinHandle<()> {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET]);

    let app = Router::new()
        .route("/fetch", get(fetch_handler))
        .layer(cors);

    println!("Server started at http://0.0.0.0:3000");

    tokio::spawn(async move {
        axum::Server::bind(&"0.0.0.0:3000".parse().unwrap())
            .serve(app.into_make_service())
            .await
            .unwrap();
    })
}

#[derive(Deserialize)]
struct FetchParams {
    url: String,
}

async fn fetch_handler(Query(params): Query<FetchParams>) -> impl IntoResponse {
    match reqwest::get(&params.url).await {
        Ok(res) => {
            match res.bytes().await {
                Ok(bytes) => ([(axum::http::header::CONTENT_TYPE, "text/html")], bytes).into_response(),
                Err(_) => ([(axum::http::header::CONTENT_TYPE, "text/plain")], "Failed to read response body").into_response(),
            }
        }
        Err(_) => ([(axum::http::header::CONTENT_TYPE, "text/plain")], "Failed to fetch").into_response(),
    }
}

#[frb]
pub async fn fetch_data_rust(codes_json: String) -> Promise {
    // サーバーが起動していなければ起動
    SERVER_HANDLE.get_or_init(|| async {
        start_server().await
    }).await;

    println!("fetch_data_rust() called!");

    let future = async move {
        // あなたのデータ取得ロジックをここで実行
        match fetch_and_scrape_multiple(&codes_json).await {
            Ok(data) => Ok(js_sys::JsString::from(&data)),
            Err(e) => Err(js_sys::JsString::from(&format!("Error: {}", e))),
        }
    };

    future_to_promise(future)
}

// あなたの非同期データ取得関数
async fn fetch_and_scrape_multiple(codes_json: &str) -> Result<String, String> {
    // 例: コードが指定されたURLから情報を取得する
    Ok("sample data".to_string())
}

fn future_to_promise(fut: impl std::future::Future<Output = Result<js_sys::JsString, js_sys::JsString>> + 'static) -> Promise {
    // `Future` を `Promise` に変換
    js_sys::Promise::new(&mut |resolve, reject| {
        tokio::spawn(async move {
            match fut.await {
                Ok(value) => resolve.call1(&JsValue::NULL, &value).unwrap(),
                Err(e) => reject.call1(&JsValue::NULL, &e).unwrap(),
            }
        });
    })
}
