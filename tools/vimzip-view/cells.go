package main

// Pictures for terminals that draw no pixels, finer than half blocks:
//
//	vimzip-view cells FILE COLS ROWS [256]
//	  first line: "WIDTHxHEIGHT FORMAT"; then the picture fitted into COLS x ROWS cells, one line per
//	  row of cells as runs "COUNT:FG:BG:CHAR": each cell split into 2 x 4 parts, the character
//	  (hex code point, an octant or a block element) that best shows which parts take the
//	  foreground color and which the background. Colors as in the image mode.

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	"os"
	"strconv"
	"strings"

	"golang.org/x/image/draw"
)

func cells(path string, cols, rows int, palette bool) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	src, format, err := image.Decode(bufio.NewReader(f))
	if err != nil {
		return err
	}
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	fmt.Fprintf(out, "%dx%d %s\n", w, h, strings.ToUpper(format))
	if w == 0 || h == 0 {
		return nil
	}
	// parts about square (a cell twice as tall as wide), the picture's shape kept
	scale := min(float64(2*cols)/float64(w), float64(4*rows)/float64(h))
	pw, ph := max(2, int(float64(w)*scale+0.5)), max(4, int(float64(h)*scale+0.5))
	pw += pw % 2
	ph += (4 - ph%4) % 4
	img := image.NewNRGBA(image.Rect(0, 0, pw, ph))
	for y := 0; y < ph; y++ {
		for x := 0; x < pw; x++ {
			v := uint8(38)
			if (x/4+y/4)%2 == 1 {
				v = 50
			}
			img.SetNRGBA(x, y, color.NRGBA{v, v, v, 255})
		}
	}
	draw.CatmullRom.Scale(img, img.Bounds(), src, b, draw.Over, nil)
	step := func(v float64) uint8 { return uint8((min(255, max(0, int(v+0.5))) + 8) / 17 * 17) }
	name := func(c [3]float64) string {
		n := color.NRGBA{step(c[0]), step(c[1]), step(c[2]), 255}
		if palette {
			return strconv.Itoa(xterm(n))
		}
		return fmt.Sprintf("%02x%02x%02x", n.R, n.G, n.B)
	}
	for cy := 0; cy < ph/4; cy++ {
		var line []string
		run, last := 0, ""
		for cx := 0; cx < pw/2; cx++ {
			var px [8][3]float64
			for i := range 8 {
				p := img.Pix[((cy*4+i/2)*pw+cx*2+i%2)*4:]
				px[i] = [3]float64{float64(p[0]), float64(p[1]), float64(p[2])}
			}
			mask, fg, bg := split(px)
			ch := octants[mask]
			if mask == 0 {
				fg = bg
			} else if mask == 255 {
				// (all foreground: a blank on that color, one character fewer to draw)
				ch, bg = ' ', fg
			}
			cell := name(fg) + ":" + name(bg) + ":" + strconv.FormatInt(int64(ch), 16)
			// (both sides the same color once rounded: a blank)
			if ch == ' ' || name(fg) == name(bg) {
				cell = name(bg) + ":" + name(bg) + ":20"
			}
			if cell != last && run > 0 {
				line = append(line, strconv.Itoa(run)+":"+last)
				run = 0
			}
			last = cell
			run++
		}
		line = append(line, strconv.Itoa(run)+":"+last)
		fmt.Fprintln(out, strings.Join(line, " "))
	}
	return nil
}

// the parts of a cell in two colors with the least difference from the picture: each pattern tried,
// its colors the averages of its two sides
func split(px [8][3]float64) (int, [3]float64, [3]float64) {
	var total [3]float64
	for _, p := range px {
		for c := range 3 {
			total[c] += p[c]
		}
	}
	best, bestErr := 0, -1.0
	var bestFg, bestBg [3]float64
	for m := 1; m < 256; m++ {
		var sum [3]float64
		n := 0
		for i := range 8 {
			if m>>i&1 == 1 {
				n++
				for c := range 3 {
					sum[c] += px[i][c]
				}
			}
		}
		var fg, bg [3]float64
		for c := range 3 {
			fg[c] = sum[c] / float64(n)
			if n < 8 {
				bg[c] = (total[c] - sum[c]) / float64(8-n)
			}
		}
		e := 0.0
		for i := range 8 {
			q := bg
			if m>>i&1 == 1 {
				q = fg
			}
			for c := range 3 {
				d := px[i][c] - q[c]
				e += d * d
			}
		}
		if bestErr < 0 || e < bestErr {
			best, bestErr, bestFg, bestBg = m, e, fg, bg
		}
	}
	return best, bestFg, bestBg
}
