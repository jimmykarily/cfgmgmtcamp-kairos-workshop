# Stage 4: Upgrading your cluster manually

Docs:
  - [Manual Upgrade](https://kairos.io/docs/upgrade/manual/)
  - [A/B Upgrades](https://kairos.io/docs/architecture/container/#ab-upgrades)

## Choose your upgrade source

You can trigger a new build and generate a new artifact (see [stage-3](stage-3.md)) but you'll need to change the pipeline so that the image is pushed to some registry from which we can pull.

Alternatively you can choose any image from the Kairos registry: https://quay.io/organization/kairos .

> **Note:** Remember, because of the "all or nothing" nature of the Kairos upgrades and upgrade is just a full OS replacement and as such, it can as well
> be a downgrade to an older image.

## Upgrade

```bash
sudo kairos-agent upgrade --source oci:<upgrade_image_here>
sudo reboot
```

✅ Done! 🎉
