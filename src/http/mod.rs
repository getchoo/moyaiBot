anyhow::Result;
use log::trace;
use serde::de::DeserializeOwned;

pub mod shiggy;
pub mod teawie;

pub type Client = reqwest::Client;
pub type Response = reqwest::Response;

/// Primary extensions for HTTP Client
pub trait Ext {
	async fn get_request(&self, url: &str) -> Result<Response>;
	async fn get_json<T: DeserializeOwned>(&self, url: &str) -> Result<T>;
	fn default() -> Self;
}

impl Ext for Client {
	fn default() -> Self {
		reqwest::ClientBuilder::new()
			.user_agent(format!(
				"moyai-discord-bot/{}",
				option_env!("CARGO_PKG_VERSION").unwrap_or("development")
			))
			.build()
			.unwrap()
	}

	async fn get_request(&self, url: &str) -> Result<Response> {
		trace!("Making request to {url}");
		let resp = self.get(url).send().await?;
		resp.error_for_status_ref()?;

		Ok(resp)
	}

	async fn get_json<T: DeserializeOwned>(&self, url: &str) -> Result<T> {
		let resp = self.get_request(url).await?;
		let json = resp.json().await?;

		Ok(json)
	}
}
