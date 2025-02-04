use crate::{client::Context, consts::Colors};

use std::env::consts::{ARCH, OS};

use anyhow::Result;
use poise::{serenity_prelude::CreateEmbed, CreateReply};

/// Get version info
#[poise::command(slash_command)]
pub async fn version(ctx: Context<'_>) -> Result<()> {
	let sha = option_env!("GIT_SHA").unwrap_or("main");
	let revision_url = format!(
		"[{}]({}/tree/{})",
		sha,
		option_env!("CARGO_PKG_REPOSITORY").unwrap_or("https://github.com/getchoo/moyai-bot"),
		sha,
	);

	let os_info = format!("{ARCH}-{OS}");

	let fields = [
		(
			"Version:",
			option_env!("CARGO_PKG_VERSION").unwrap_or("not found"),
			false,
		),
		("OS:", &os_info, false),
		("Revision:", &revision_url, false),
	];

	let embed = CreateEmbed::new()
		.title("Version Information")
		.description("now with over 9000 more builders!")
		.fields(fields)
		.color(Colors::Blue);
	let message = CreateReply::default().embed(embed);

	ctx.send(message).await?;

	Ok(())
}
