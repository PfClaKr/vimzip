// vimzip-view: images and PDFs for vim, which has no pixels.
//
//	vimzip-view image FILE COLS ROWS [256]
//	  first line: "WIDTHxHEIGHT FORMAT"; then the picture fitted into COLS x ROWS cells, one line per
//	  row of cells as runs "COUNT:TOP:BOTTOM" (each cell is a half block: two square pixels), the
//	  colors as rrggbb in 16 steps a channel, or xterm-256 numbers with the 256 argument
//	vimzip-view pdf FILE
//	  the text, pages separated by form feeds (for when pdftotext is not installed)
//	vimzip-view sixel|kitty FILE COLS ROWS CELLW CELLH
//	  the picture in real pixels, for terminals that can draw them (see pixels.go)
package main

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"
	"sort"
	"strconv"
	"strings"

	"github.com/ledongthuc/pdf"
	_ "golang.org/x/image/bmp"
	_ "golang.org/x/image/tiff"
	_ "golang.org/x/image/webp"
)

func main() {
	defer func() {
		if r := recover(); r != nil {
			fmt.Fprintln(os.Stderr, "vimzip-view:", r)
			os.Exit(1)
		}
	}()
	var err error
	switch {
	case len(os.Args) >= 5 && os.Args[1] == "image":
		cols, _ := strconv.Atoi(os.Args[3])
		rows, _ := strconv.Atoi(os.Args[4])
		err = picture(os.Args[2], max(cols, 1), max(rows, 1), len(os.Args) > 5 && os.Args[5] == "256")
	case len(os.Args) == 7 && (os.Args[1] == "sixel" || os.Args[1] == "kitty"):
		var n [4]int
		for i := range n {
			n[i], _ = strconv.Atoi(os.Args[3+i])
			n[i] = max(n[i], 1)
		}
		err = pixels(os.Args[1], os.Args[2], n[0], n[1], n[2], n[3])
	case len(os.Args) == 3 && os.Args[1] == "pdf":
		err = text(os.Args[2])
	default:
		err = fmt.Errorf("usage: vimzip-view image FILE COLS ROWS [256] | pdf FILE | sixel|kitty FILE COLS ROWS CELLW CELLH")
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "vimzip-view:", err)
		os.Exit(1)
	}
}

func picture(path string, cols, rows int, palette bool) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	img, format, err := image.Decode(f)
	if err != nil {
		return err
	}
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	fmt.Fprintf(out, "%dx%d %s\n", w, h, strings.ToUpper(format))
	if w == 0 || h == 0 {
		return nil
	}
	// fit cols x (2 * rows) square pixels, keeping the shape
	scale := math.Min(float64(cols)/float64(w), float64(2*rows)/float64(h))
	ow, oh := max(1, int(float64(w)*scale)), max(1, int(float64(h)*scale))
	oh += oh % 2
	px := make([]color.NRGBA, ow*oh)
	for y := 0; y < oh; y++ {
		for x := 0; x < ow; x++ {
			px[y*ow+x] = sample(img, b, float64(x)/scale, float64(y)/scale, 1/scale, x, y)
		}
	}
	// truecolor in 16 steps a channel: vim needs a highlight group per color and has room for about
	// 20000 in all (E849), which a few colorful pictures at full color used up
	step := func(v uint8) uint8 { return uint8((int(v) + 8) / 17 * 17) }
	name := func(c color.NRGBA) string {
		if palette {
			return strconv.Itoa(xterm(c))
		}
		return fmt.Sprintf("%02x%02x%02x", step(c.R), step(c.G), step(c.B))
	}
	for y := 0; y < oh; y += 2 {
		var line []string
		run, last := 0, ""
		for x := 0; x < ow; x++ {
			cell := name(px[y*ow+x]) + ":" + name(px[(y+1)*ow+x])
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

// the average of up to 4x4 points in the source area of one output pixel, over a checkerboard
// where the picture is transparent
func sample(img image.Image, b image.Rectangle, sx, sy, step float64, ox, oy int) color.NRGBA {
	n := min(4, max(1, int(step)))
	var r, g, bl, a float64
	for j := 0; j < n; j++ {
		for i := 0; i < n; i++ {
			x := b.Min.X + min(b.Dx()-1, int(sx+(float64(i)+0.5)*step/float64(n)))
			y := b.Min.Y + min(b.Dy()-1, int(sy+(float64(j)+0.5)*step/float64(n)))
			c := color.NRGBAModel.Convert(img.At(x, y)).(color.NRGBA)
			al := float64(c.A) / 255
			r, g, bl, a = r+float64(c.R)*al, g+float64(c.G)*al, bl+float64(c.B)*al, a+al
		}
	}
	k := float64(n * n)
	bg := 38.0
	if (ox/4+oy/4)%2 == 1 {
		bg = 50
	}
	mix := func(v float64) uint8 { return uint8(math.Round(v/k + bg*(1-a/k))) }
	return color.NRGBA{mix(r), mix(g), mix(bl), 255}
}

// the nearest of the xterm 6x6x6 cube and its gray ramp
func xterm(c color.NRGBA) int {
	steps := []int{0, 95, 135, 175, 215, 255}
	near := func(v uint8) int {
		best := 0
		for i, s := range steps {
			if abs(int(v)-s) < abs(int(v)-steps[best]) {
				best = i
			}
		}
		return best
	}
	r, g, b := near(c.R), near(c.G), near(c.B)
	cube := 16 + 36*r + 6*g + b
	dc := dist(c, steps[r], steps[g], steps[b])
	gray := min(23, max(0, (int(c.R)+int(c.G)+int(c.B))/3-3)/10)
	v := 8 + 10*gray
	if dist(c, v, v, v) < dc {
		return 232 + gray
	}
	return cube
}

func dist(c color.NRGBA, r, g, b int) int {
	dr, dg, db := int(c.R)-r, int(c.G)-g, int(c.B)-b
	return dr*dr + dg*dg + db*db
}

func abs(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

func text(path string) error {
	f, r, err := pdf.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	for i := 1; i <= r.NumPage(); i++ {
		if i > 1 {
			fmt.Fprint(out, "\f")
		}
		p := r.Page(i)
		if p.V.IsNull() {
			continue
		}
		rows, err := p.GetTextByRow()
		if err != nil {
			continue
		}
		// top of the page first (Position grows downward); words joined with a space at a gap
		sort.SliceStable(rows, func(a, b int) bool { return rows[a].Position < rows[b].Position })
		for _, row := range rows {
			var line strings.Builder
			end := -1.0
			for _, t := range row.Content {
				if end >= 0 && t.X-end > t.FontSize*0.15 && !strings.HasSuffix(line.String(), " ") {
					line.WriteString(" ")
				}
				line.WriteString(t.S)
				end = t.X + t.W
			}
			fmt.Fprintln(out, strings.Join(strings.Fields(line.String()), " "))
		}
	}
	return nil
}
