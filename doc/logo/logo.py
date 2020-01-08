#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.font_manager as font_manager
from PIL import Image, ImageChops


def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0, 0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)


def mysinc(array, factor, reduce_sin=False):
    out = []
    period_zero = 2*np.pi/factor
    for x in array:
        if x < period_zero:
            out.append(0.0)
        elif x > 8*period_zero and reduce_sin is True:
            out.append(0.0)
        else:
            out.append(np.sin(x*factor)/(factor**x))
    return out


def apply_color_and_width(color, sinus_list):
    s1 = 10
    s2 = 4
    s3 = 2

    if color == "green":
        if len(sinus_list) > 0:
            plt.setp(sinus_list[0], linewidth=s1, color='lawngreen')
        if len(sinus_list) > 1:
            plt.setp(sinus_list[1], linewidth=s2, color='yellowgreen')
        if len(sinus_list) > 2:
            plt.setp(sinus_list[2], linewidth=s3, color='olive')

    elif color == "blue":
        if len(sinus_list) > 0:
            plt.setp(sinus_list[0], linewidth=s1, color='cornflowerblue')
        if len(sinus_list) > 1:
            plt.setp(sinus_list[1], linewidth=s2, color='royalblue')
        if len(sinus_list) > 2:
            plt.setp(sinus_list[2], linewidth=s3, color='midnightblue')

    elif color == "red":
        if len(sinus_list) > 0:
            plt.setp(sinus_list[0], linewidth=s1, color='tomato')
        if len(sinus_list) > 1:
            plt.setp(sinus_list[1], linewidth=s2, color='red')
        if len(sinus_list) > 2:
            plt.setp(sinus_list[2], linewidth=s3, color='brown')


def print_line(color, width=1200):
    dpi = 80
    length = (width / dpi) + 1
    scale_factor = length/12.3

    fig = plt.figure(figsize=(length, 10))
    plt.axis('off')
    ax = fig.add_subplot(111)
    ax.set_autoscaley_on(False)
    ax.set_xlim([0, int(49*scale_factor)])
    ax.set_ylim([-1, 1])

    x = np.linspace(0, int(133*scale_factor), int(133*scale_factor)*10)
    l1 = ax.plot(x, x*0)
    l2 = ax.plot(x, x*0)
    l3 = ax.plot(x, x*0)

    apply_color_and_width(color, [l1, l2, l3])

    im_name = "line-{}.png".format(color)
    fig.savefig(im_name, transparent=True, bbox_inches='tight', pad_inches=0)

    # Crop image
    im = Image.open(im_name)
    im = trim(im)
    im.save('line-{}_{}x{}.png'.format(color, im.size[0], im.size[1]))


def print_logo(color, width=1200, small=False):
    reduce_sin = True if width <= 1200 else False
    dpi = 80
    length = (width / dpi) + 1
    scale_factor = length/12.3

    fig = plt.figure(figsize=(length, 10))
    plt.axis('off')
    ax = fig.add_subplot(111)
    ax.set_autoscaley_on(False)
    ax.set_xlim([0, int(49*scale_factor)])
    ax.set_ylim([-1, 1])

    if small is True:
        x = np.linspace(6.35, 7.805, 50)
        l1 = ax.plot(x, mysinc(x, 1.1, reduce_sin))
        apply_color_and_width(color, [l1])

    else:
        x = np.linspace(0, int(133*scale_factor), int(133*scale_factor)*10)
        l1 = ax.plot(x, mysinc(x, 1.1, reduce_sin))
        l2 = ax.plot(x, mysinc(x, 1.2, reduce_sin))
        l3 = ax.plot(x, mysinc(x, 1.3, reduce_sin))
        apply_color_and_width(color, [l1, l2, l3])

    if width < 1200:
        pos_xy = (0.1, 0.535)
    else:
        pos_xy = (0, 0.535)

    ax.annotate("W VECRUNCHER", xy=pos_xy,
                horizontalalignment='left', verticalalignment='top',
                color='midnightblue',
                fontproperties=font)
    im_name = "logo-{}.png".format(color)
    fig.savefig(im_name, transparent=True, bbox_inches='tight', pad_inches=0)

    # Crop image
    im = Image.open(im_name)
    im = trim(im)
    if small is True:
        im.save('logo-small-{}_{}x{}.png'.format(color, im.size[0], im.size[1]))
    else:
        im.save('logo-{}_{}x{}.png'.format(color, im.size[0], im.size[1]))


# for font in font_manager.findSystemFonts():
#     print(font)

font = font_manager.FontProperties(family='sans-serif', style='italic', weight='heavy', size=75)

print_logo('blue', 900, small=True)

print_logo('blue', 900, small=False)
print_logo('blue', 1400, small=False)
print_logo('blue', 3000, small=False)
print_logo('blue', 4000, small=False)

print_line('blue', 900)
print_line('blue', 1400)
print_line('blue', 3000)
print_line('blue', 4000)
