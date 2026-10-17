// SPDX-License-Identifier: GPL-2.0
/*
 * NXP P61/P73 eSE SPI character device (/dev/p73) for the QTI nq-nci NFC driver.
 *
 * Reduced port of OnePlusOSS drivers/nfc/ese/p73.c (Copyright (C) 2012-2014
 * NXP Semiconductors, Apache-2.0 / GPL): the pn5xx/pn544 power ioctls are
 * replaced by nqx_ese_pwr_ext() exported from nq-nci.c.
 */
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/miscdevice.h>
#include <linux/mutex.h>
#include <linux/spi/spi.h>
#include <linux/of.h>
#include <linux/ioctl.h>

#define P61_MAGIC 0xEA
#define P61_SET_PWR		_IOW(P61_MAGIC, 0x01, long)
#define P61_SET_DBG		_IOW(P61_MAGIC, 0x02, long)
#define P61_SET_POLL		_IOW(P61_MAGIC, 0x03, long)
#define P61_SET_SPM_PWR		_IOW(P61_MAGIC, 0x04, long)
#define P61_GET_SPM_STATUS	_IOR(P61_MAGIC, 0x05, long)
#define P61_SET_THROUGHPUT	_IOW(P61_MAGIC, 0x06, long)
#define P61_GET_ESE_ACCESS	_IOW(P61_MAGIC, 0x07, long)
#define P61_SET_POWER_SCHEME	_IOW(P61_MAGIC, 0x08, long)
#define P61_SET_DWNLD_STATUS	_IOW(P61_MAGIC, 0x09, long)
#define P61_INHIBIT_PWR_CNTRL	_IOW(P61_MAGIC, 0x0A, long)

#define MAX_BUFFER_SIZE	780
#define P61_SPI_CLOCK	7000000

/* nq-nci.c: arg 0 = eSE power on, 1 = off, 3 = read state */
extern int nqx_ese_pwr_ext(unsigned long arg);

struct p61_dev {
	struct miscdevice misc;
	struct spi_device *spi;
	struct mutex io_mutex;
	unsigned char *kbuf;
	bool pwr_on;
};

static struct p61_dev *g_p61;


static int p61_power(struct p61_dev *d, bool on)
{
	int r;

	if (d->pwr_on == on)
		return 0;
	r = nqx_ese_pwr_ext(on ? 0 : 1);
	if (r < 0)
		dev_err(&d->spi->dev, "eSE power %s failed: %d\n",
			on ? "on" : "off", r);
	else
		d->pwr_on = on;
	return r;
}

static int p61_open(struct inode *inode, struct file *filp)
{
	struct p61_dev *d = g_p61;

	if (!d)
		return -ENODEV;
	filp->private_data = d;
	mutex_lock(&d->io_mutex);
	/* The HAL asks the NFC HAL (not present on LineageOS) to power the
	 * eSE; keep the rail up while the node is open instead. */
	p61_power(d, true);
	mutex_unlock(&d->io_mutex);
	return 0;
}

static int p61_release(struct inode *inode, struct file *filp)
{
	return 0;
}

static ssize_t p61_read(struct file *filp, char __user *buf, size_t count,
			loff_t *off)
{
	struct p61_dev *d = filp->private_data;
	int ret;

	if (count > MAX_BUFFER_SIZE)
		count = MAX_BUFFER_SIZE;
	mutex_lock(&d->io_mutex);
	memset(d->kbuf, 0, MAX_BUFFER_SIZE);
	ret = spi_read(d->spi, d->kbuf, count);
	if (ret < 0) {
		ret = -EIO;
	} else if (copy_to_user(buf, d->kbuf, count)) {
		ret = -EFAULT;
	} else {
		ret = count;
	}
	mutex_unlock(&d->io_mutex);
	return ret;
}

static ssize_t p61_write(struct file *filp, const char __user *buf,
			 size_t count, loff_t *off)
{
	struct p61_dev *d = filp->private_data;
	int ret;

	if (count > MAX_BUFFER_SIZE)
		count = MAX_BUFFER_SIZE;
	mutex_lock(&d->io_mutex);
	if (copy_from_user(d->kbuf, buf, count)) {
		ret = -EFAULT;
	} else {
		ret = spi_write(d->spi, d->kbuf, count);
		ret = ret < 0 ? -EIO : count;
	}
	mutex_unlock(&d->io_mutex);
	return ret;
}

static long p61_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	struct p61_dev *d = filp->private_data;
	long ret = 0;

	mutex_lock(&d->io_mutex);
	switch (cmd) {
	case P61_SET_SPM_PWR:
		/* NXP convention: 1 = enable, 0 = disable (2 = reset: no-op) */
		if (arg == 1)
			ret = p61_power(d, true);
		else if (arg == 0)
			ret = p61_power(d, false);
		break;
	case P61_GET_SPM_STATUS:
		ret = nqx_ese_pwr_ext(3);
		break;
	case P61_SET_PWR:
	case P61_SET_DBG:
	case P61_SET_POLL:
	case P61_SET_THROUGHPUT:
	case P61_SET_POWER_SCHEME:
	case P61_SET_DWNLD_STATUS:
	case P61_INHIBIT_PWR_CNTRL:
		break;
	case P61_GET_ESE_ACCESS:
		/* eSE access is always granted */
		ret = 0;
		break;
	default:
		ret = -ENOTTY;
	}
	mutex_unlock(&d->io_mutex);
	return ret;
}

static const struct file_operations p61_fops = {
	.owner = THIS_MODULE,
	.read = p61_read,
	.write = p61_write,
	.open = p61_open,
	.release = p61_release,
	.unlocked_ioctl = p61_ioctl,
	.compat_ioctl = p61_ioctl,
};

static int p61_probe(struct spi_device *spi)
{
	struct p61_dev *d;
	int ret;

	d = kzalloc(sizeof(*d), GFP_KERNEL);
	if (!d)
		return -ENOMEM;
	d->kbuf = kzalloc(MAX_BUFFER_SIZE, GFP_KERNEL);
	if (!d->kbuf) {
		kfree(d);
		return -ENOMEM;
	}
	mutex_init(&d->io_mutex);

	spi->bits_per_word = 8;
	spi->mode = SPI_MODE_0;
	spi->max_speed_hz = P61_SPI_CLOCK;
	ret = spi_setup(spi);
	if (ret < 0) {
		dev_err(&spi->dev, "spi_setup failed: %d\n", ret);
		goto err;
	}

	d->spi = spi;
	d->misc.minor = MISC_DYNAMIC_MINOR;
	d->misc.name = "p73";
	d->misc.fops = &p61_fops;
	d->misc.parent = &spi->dev;
	spi_set_drvdata(spi, d);
	ret = misc_register(&d->misc);
	if (ret < 0) {
		dev_err(&spi->dev, "misc_register failed: %d\n", ret);
		goto err;
	}
	g_p61 = d;
	dev_info(&spi->dev, "p73 eSE node registered (cs %d, bus %d)\n",
		 spi->chip_select, spi->master->bus_num);
	return 0;
err:
	kfree(d->kbuf);
	kfree(d);
	return ret;
}

static int p61_remove(struct spi_device *spi)
{
	struct p61_dev *d = spi_get_drvdata(spi);

	g_p61 = NULL;
	misc_deregister(&d->misc);
	kfree(d->kbuf);
	kfree(d);
	return 0;
}

static const struct of_device_id p61_dt_match[] = {
	{ .compatible = "nxp,p61" },
	{}
};

static struct spi_driver p61_driver = {
	.driver = {
		.name = "p61",
		.of_match_table = p61_dt_match,
	},
	.probe = p61_probe,
	.remove = p61_remove,
};
module_spi_driver(p61_driver);

MODULE_DESCRIPTION("NXP P61/P73 eSE SPI driver (nq-nci power glue)");
MODULE_LICENSE("GPL");
