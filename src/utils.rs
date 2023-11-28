use crate::{colors, consts, Context, Error};

use log::*;
use once_cell::sync::Lazy;
use poise::serenity_prelude as serenity;
use rand::seq::SliceRandom;
use serenity::{CreateEmbed, GuildId, Message};
use url::Url;

pub fn parse_snowflake_from_env<T, F: Fn(u64) -> T>(key: &str, f: F) -> Option<T> {
	std::env::var(key).ok().and_then(|v| v.parse().map(&f).ok())
}
pub fn parse_snowflakes_from_env<T, F: Fn(u64) -> T>(key: &str, f: F) -> Option<Vec<T>> {
	std::env::var(key).ok().and_then(|gs| {
		gs.split(',')
			.map(|g| g.parse().map(&f))
			.collect::<Result<Vec<_>, _>>()
			.ok()
	})
}
/*
 * chooses a random element from an array
 */
pub fn random_choice<const N: usize>(arr: [&str; N]) -> Result<String, Error> {
	let mut rng = rand::thread_rng();
	if let Some(resp) = arr.choose(&mut rng) {
		Ok((*resp).to_string())
	} else {
		Err(Into::into("couldn't choose from arr!"))
	}
}

// waiting for `round_char_boundary` to stabilize
pub fn floor_char_boundary(s: &str, index: usize) -> usize {
	if index >= s.len() {
		s.len()
	} else {
		let lower_bound = index.saturating_sub(3);
		let new_index = s.as_bytes()[lower_bound..=index]
			.iter()
			.rposition(|&b| (b as i8) >= -0x40); // b.is_utf8_char_boundary

		// Can be made unsafe but whatever
		lower_bound + new_index.unwrap()
	}
}

pub fn is_guild_allowed(gid: GuildId) -> bool {
	static ALLOWED_GUILDS: Lazy<Vec<GuildId>> = Lazy::new(|| {
		parse_snowflakes_from_env("ALLOWED_GUILDS", GuildId)
			.unwrap_or_else(|| vec![consts::TEAWIE_GUILD, GuildId(1091969030694375444)])
	});

	ALLOWED_GUILDS.contains(&gid)
}

pub async fn send_url_as_embed(ctx: Context<'_>, url: String) -> Result<(), Error> {
	match Url::parse(&url) {
		Ok(parsed) => {
			let title = parsed
				.path_segments()
				.unwrap()
				.last()
				.unwrap_or("image")
				.replace("%20", " ");

			ctx.send(|c| {
				c.embed(|e| {
					e.title(title)
						.image(&url)
						.url(url)
						.color(colors::Colors::Blue)
				})
			})
			.await?;
		}
		Err(why) => {
			error!("failed to parse url {}! {}", url, why);
			ctx.say("i can't get that for you right now :(").await?;
		}
	}

	Ok(())
}

pub async fn resolve_message_to_embed(ctx: &serenity::Context, msg: &Message) -> CreateEmbed {
	let truncation_point = floor_char_boundary(&msg.content, 700);
	let truncated_content = if msg.content.len() <= truncation_point {
		msg.content.to_string()
	} else {
		format!("{}...", &msg.content[..truncation_point])
	};

	let color = msg
		.member(ctx)
		.await
		.ok()
		.and_then(|m| m.highest_role_info(&ctx.cache))
		.and_then(|(role, _)| role.to_role_cached(&ctx.cache))
		.map(|role| role.colour);

	let attached_image = msg
		.attachments
		.iter()
		.filter(|a| {
			a.content_type
				.as_ref()
				.filter(|ct| ct.contains("image/"))
				.is_some()
		})
		.map(|a| &a.url)
		.next();

	let attachments_len = msg.attachments.len();

	let mut embed = msg
		.embeds
		.first()
		.map(|embed| CreateEmbed::from(embed.clone()))
		.unwrap_or_default();

	embed.author(|author| author.name(&msg.author.name).icon_url(&msg.author.face()));

	if let Some(color) = color {
		embed.color(color);
	}

	if let Some(attachment) = attached_image {
		embed.image(attachment);
	}

	if attachments_len > 1 {
		embed.footer(|footer| {
			// yes it will say '1 attachments' no i do not care
			footer.text(format!("{} attachments", attachments_len))
		});
	}

	embed.description(truncated_content);
	embed
}
