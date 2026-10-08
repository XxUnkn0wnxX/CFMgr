# 🚀 User setup guide

[← README](../README.md) · [Compatibility](compatibility.md) · [Developer guide](development.md)

![Guide](https://img.shields.io/badge/guide-user_setup-0051c3)
![Project stage](https://img.shields.io/badge/CFMgr-in_development-orange)

Prepare your Cloudflare account and DNS before setting up DDNS or a public
tunnel hostname. CFMgr is still being implemented; this guide currently covers
those prerequisites. Tested CFMgr installation and feature walkthroughs will
follow when the manager is ready.

## ☁️ Create your Cloudflare account

Create an account or sign in at the [Cloudflare dashboard](https://dash.cloudflare.com/sign-up).
Use an account that can manage the domain and the features you intend to use.
Cloudflare lists an account and a domain on Cloudflare as prerequisites for
publishing applications through a named tunnel. See its
[Tunnel getting-started guide](https://developers.cloudflare.com/tunnel/get-started/).

<details>
<summary>Cloudflare and cloudflared</summary>

**Cloudflare** is the service where you manage the account, domain, DNS and
tunnels. **cloudflared** is the connector program that runs on the router.
There is no separate cloudflared account to create.

</details>

## 🌐 Put your domain's DNS on Cloudflare

Your domain can be registered with Cloudflare or another registrar. For the
usual full DNS setup, Cloudflare becomes its authoritative DNS provider while
the registration can remain elsewhere. Follow Cloudflare's
[full setup instructions](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/)
alongside these steps:

1. **Add the domain to your Cloudflare account.** Add the registered domain,
   such as `example.com`, rather than a URL containing `https://` or a page path.
2. **Review the DNS records.** Compare the imported records with your existing
   DNS provider and retain the records needed by your website, email and other
   services.
3. **Complete nameserver setup.** For a domain registered elsewhere, use the
   exact Cloudflare-assigned nameservers at your registrar. Follow the official
   instructions for any existing DNSSEC setup as part of that change. A domain
   already using Cloudflare DNS may have completed this step.
4. **Wait for the zone to become active.** Confirm the domain is active in the
   Cloudflare dashboard and its DNS records are managed there before proceeding
   with CFMgr's DDNS or public-hostname setup.

Changing the router's DNS resolver to `1.1.1.1` does not move your domain's DNS
to Cloudflare. The domain's authoritative DNS setup is what matters here.

> 📷 **Screenshot placeholder:** Cloudflare domain overview with the zone shown
> as active. Replace the personal domain and account details with sanitized values.

## 🧩 Prepare the router and selected features

Review the [compatibility guide](compatibility.md) for the measured Merlin
target, Entware prerequisites and remaining acceptance limits. The current
development work is not a declaration that every listed firmware is supported.

| Feature | Prepare |
| --- | --- |
| DDNS | An active Cloudflare DNS zone and the hostnames/records you want CFMgr to manage. |
| Public tunnel hostname | Your Cloudflare account, domain and the local application you want the tunnel to reach. |
| IP-Sync | The intended Cloudflare Zero Trust IP list and the Access policy that uses it; DNS setup is separate from list synchronization. |

Feature-specific credential permissions, CFMgr menus and setup commands will be
documented with their validated implementations. CFMgr's scope does not include
registering domains or changing registrar nameservers; complete those steps in
Cloudflare and your registrar first.

> 📷 **Screenshot placeholder:** The completed CFMgr main menu and feature setup
> screens, captured after runtime validation with credentials and identifiers hidden.
