using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Drawing;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Drawing.Drawing2D;

namespace Editor
{
    public partial class Cursor : UserControl
    {
        private Pen whitePen;
        private Pen blackPen;
        private Image background;

        private Rectangle srcRect;
        private Point mouse;

        public Cursor()
        {
            InitializeComponent();

            whitePen = new Pen(Color.White, 2);
            blackPen = new Pen(Color.Black, 1);
            whitePen.Alignment = PenAlignment.Inset;
            Size = new Size(DataManager.Instance.TileWidth, DataManager.Instance.TileHeight);
            this.TilesetImage = Image.FromFile(DataManager.Instance.TilesetImage);

            this.BackColor = Color.Transparent;
            this.ForeColor = Color.Transparent;

            Graphics g = CreateGraphics();

            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            var state = g.Save();

            g.DrawImage(TilesetImage, 0, 0, srcRect, GraphicsUnit.Pixel);
            g.DrawRectangle(whitePen, 0, 0, tw, th);
            g.DrawRectangle(blackPen, 0, 0, tw, th);
            g.DrawRectangle(blackPen, 2, 2, tw - 4, th - 4);

            g.Restore(state);
        }

        public Rectangle SrcRect
        {
            set
            {
                this.srcRect = value;
            }

            get
            {
                return this.srcRect;
            }
        }

        public Point Mouse
        {
            set
            {
                this.mouse = value;
            }

            get
            {
                return this.mouse;
            }
        }

        public Image TilesetImage
        {
            get
            {
                return background;
            }

            set
            {
                background = value;
            }
        }
    }
}
