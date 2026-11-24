package main

// Pictures in real pixels, for terminals that can draw them:
//
//	vimzip-view sixel FILE COLS ROWS CELLW CELLH
//	vimzip-view kitty FILE COLS ROWS CELLW CELLH
//	  (FILE - is the input)
//	  the picture fitted into COLS x ROWS cells of CELLW x CELLH screen pixels (made smaller, never
//	  larger). First line: "WIDTHxHEIGHT FORMAT C R", the picture's size and format and the cells it
//	  takes. Then for sixel one line, a DCS sequence to write to the terminal as it is (xterm, foot,
//	  WezTerm, Konsole, Windows Terminal, VTE built with sixel); for kitty a line with the PNG in
//	  base64, then R lines of C placeholders (U+10EEEE with the marks of their row and column) to put
//	  in the text, colored with the image's number (kitty, Ghostty)

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"fmt"
	"image"
	"image/color"
	"image/png"
	"os"
	"sort"
	"strconv"
	"strings"

	"golang.org/x/image/draw"
)

func pixels(kind, path string, cols, rows, cw, ch int) error {
	maxW, maxH := cols*cw, rows*ch
	// (- reads it from the input: a PDF's page from pdftoppm)
	f := os.Stdin
	if path != "-" {
		var err error
		if f, err = os.Open(path); err != nil {
			return err
		}
		defer f.Close()
	}
	src, format, err := image.Decode(bufio.NewReader(f))
	if err != nil {
		return err
	}
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	if w == 0 || h == 0 {
		return fmt.Errorf("empty picture")
	}
	scale := min(1, float64(maxW)/float64(w), float64(maxH)/float64(h))
	ow, oh := max(1, int(float64(w)*scale+0.5)), max(1, int(float64(h)*scale+0.5))
	// over a checkerboard where it is transparent, as image viewers show it
	img := image.NewNRGBA(image.Rect(0, 0, ow, oh))
	for y := 0; y < oh; y++ {
		for x := 0; x < ow; x++ {
			v := uint8(38)
			if (x/8+y/8)%2 == 1 {
				v = 50
			}
			img.SetNRGBA(x, y, color.NRGBA{v, v, v, 255})
		}
	}
	draw.CatmullRom.Scale(img, img.Bounds(), src, b, draw.Over, nil)
	out := bufio.NewWriterSize(os.Stdout, 1<<16)
	defer out.Flush()
	c, r := (ow+cw-1)/cw, (oh+ch-1)/ch
	fmt.Fprintf(out, "%dx%d %s %d %d\n", w, h, strings.ToUpper(format), c, r)
	if kind == "kitty" {
		var buf bytes.Buffer
		if err := (&png.Encoder{CompressionLevel: png.BestSpeed}).Encode(&buf, img); err != nil {
			return err
		}
		out.WriteString(base64.StdEncoding.EncodeToString(buf.Bytes()))
		out.WriteString("\n")
		// each row's first cell says its row and column; the others follow on from it
		for y := 0; y < min(r, len(diacritics)); y++ {
			out.WriteString(string([]rune{0x10EEEE, diacritics[y], diacritics[0]}))
			out.WriteString(strings.Repeat(string(rune(0x10EEEE)), c-1))
			out.WriteString("\n")
		}
		return nil
	}
	sixel(out, img)
	return nil
}

// ─── sixel ───────────────────────────────────────────────────────────────────────────────────────

// up to 256 colors picked for the picture (median cut), the pixels dithered to them
func sixel(out *bufio.Writer, img *image.NRGBA) {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	pal := medianCut(img, 255)
	idx := dither(img, pal)
	// DCS P1=0 (square pixels) P2=1 (unset pixels stay as they were) q, the size, the palette
	fmt.Fprintf(out, "\x1bP0;1;0q\"1;1;%d;%d", w, h)
	for i, c := range pal {
		fmt.Fprintf(out, "#%d;2;%d;%d;%d", i, int(c.R)*100/255, int(c.G)*100/255, int(c.B)*100/255)
	}
	masks := make([][]byte, len(pal))
	for y0 := 0; y0 < h; y0 += 6 {
		var used []int
		for y := y0; y < min(h, y0+6); y++ {
			bit := byte(1) << (y - y0)
			row := idx[y*w : (y+1)*w]
			for x, c := range row {
				if masks[c] == nil {
					masks[c] = make([]byte, w)
					used = append(used, int(c))
				}
				masks[c][x] |= bit
			}
		}
		sort.Ints(used)
		for n, c := range used {
			if n > 0 {
				out.WriteByte('$') // back to the band's start for the next color
			}
			out.WriteByte('#')
			out.WriteString(strconv.Itoa(c))
			m := masks[c]
			for x := 0; x < w; {
				v := m[x]
				run := 1
				for x+run < w && m[x+run] == v {
					run++
				}
				ch := byte(63 + v)
				if run > 3 {
					out.WriteByte('!')
					out.WriteString(strconv.Itoa(run))
					out.WriteByte(ch)
				} else {
					for i := 0; i < run; i++ {
						out.WriteByte(ch)
					}
				}
				x += run
			}
			masks[c] = nil
		}
		out.WriteByte('-')
	}
	out.WriteString("\x1b\\")
}

type box struct{ px []color.NRGBA }

func (b box) span() (int, int) {
	lo, hi := [3]int{255, 255, 255}, [3]int{}
	for _, p := range b.px {
		for i, v := range [3]int{int(p.R), int(p.G), int(p.B)} {
			lo[i], hi[i] = min(lo[i], v), max(hi[i], v)
		}
	}
	best, size := 0, -1
	for i := range 3 {
		if hi[i]-lo[i] > size {
			best, size = i, hi[i]-lo[i]
		}
	}
	return best, size
}

func medianCut(img *image.NRGBA, n int) []color.NRGBA {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	// (a sample of the pixels is enough to pick the colors)
	step := max(1, w*h/200000)
	var all []color.NRGBA
	for i := 0; i < w*h; i += step {
		p := img.Pix[i*4 : i*4+4]
		all = append(all, color.NRGBA{p[0], p[1], p[2], 255})
	}
	boxes := []box{{all}}
	for len(boxes) < n {
		best, bestSize, ch := -1, 0, 0
		for i, b := range boxes {
			if len(b.px) < 2 {
				continue
			}
			c, s := b.span()
			if s > bestSize {
				best, bestSize, ch = i, s, c
			}
		}
		if best < 0 {
			break
		}
		px := boxes[best].px
		key := func(p color.NRGBA) uint8 { return [3]uint8{p.R, p.G, p.B}[ch] }
		sort.Slice(px, func(a, b int) bool { return key(px[a]) < key(px[b]) })
		mid := len(px) / 2
		boxes[best] = box{px[:mid]}
		boxes = append(boxes, box{px[mid:]})
	}
	pal := make([]color.NRGBA, 0, len(boxes))
	for _, b := range boxes {
		var r, g, bl int
		for _, p := range b.px {
			r, g, bl = r+int(p.R), g+int(p.G), bl+int(p.B)
		}
		k := max(1, len(b.px))
		pal = append(pal, color.NRGBA{uint8(r / k), uint8(g / k), uint8(bl / k), 255})
	}
	return pal
}

// Floyd-Steinberg: each pixel to its nearest palette color, the difference passed on to the next ones
func dither(img *image.NRGBA, pal []color.NRGBA) []uint8 {
	w, h := img.Rect.Dx(), img.Rect.Dy()
	cache := map[int]uint8{}
	nearest := func(r, g, b int) uint8 {
		k := (r>>2)<<12 | (g>>2)<<6 | b>>2
		if c, ok := cache[k]; ok {
			return c
		}
		best, bd := 0, 1<<30
		for i, p := range pal {
			dr, dg, db := r-int(p.R), g-int(p.G), b-int(p.B)
			if d := dr*dr*3 + dg*dg*4 + db*db*2; d < bd {
				best, bd = i, d
			}
		}
		cache[k] = uint8(best)
		return uint8(best)
	}
	cur := make([][3]int, w+2)
	next := make([][3]int, w+2)
	idx := make([]uint8, w*h)
	clamp := func(v int) int { return min(255, max(0, v)) }
	for y := 0; y < h; y++ {
		for x := 0; x < w; x++ {
			p := img.Pix[(y*w+x)*4:]
			r := clamp(int(p[0]) + cur[x+1][0]/16)
			g := clamp(int(p[1]) + cur[x+1][1]/16)
			b := clamp(int(p[2]) + cur[x+1][2]/16)
			c := nearest(r, g, b)
			idx[y*w+x] = c
			q := pal[c]
			e := [3]int{r - int(q.R), g - int(q.G), b - int(q.B)}
			for i := range 3 {
				cur[x+2][i] += e[i] * 7
				next[x][i] += e[i] * 3
				next[x+1][i] += e[i] * 5
				next[x+2][i] += e[i]
			}
		}
		cur, next = next, cur
		for i := range next {
			next[i] = [3]int{}
		}
	}
	return idx
}
