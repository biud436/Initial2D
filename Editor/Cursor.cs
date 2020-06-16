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
    public partial class TileCursor : UserControl
    {
        private Image background;

        private Rectangle srcRect;
        private Point mouse;

        public TileCursor()
        {
            InitializeComponent();

            Size = new Size(DataManager.Instance.TileWidth, DataManager.Instance.TileHeight);
            this.TilesetImage = Image.FromFile(DataManager.Instance.TilesetImage);

            this.BackColor = Color.Transparent;

            SetStyle(ControlStyles.OptimizedDoubleBuffer |
                    ControlStyles.ResizeRedraw |
                    ControlStyles.UserPaint, false);

            ResizeRedraw = true;
            DoubleBuffered = true;

            BackgroundImage = null;

            this.Visible = true;
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x00000020; // add this
                return cp;
            }
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

        protected override void OnPaint(PaintEventArgs e)
        {
            var g = e.Graphics;

            g.Clear(this.BackColor);

            var rect = new Rectangle(0, 0, ClientSize.Width, ClientSize.Height);
            var tw = rect.Width;
            var th = rect.Height;

            g.DrawImage(TilesetImage, 0, 0, srcRect, GraphicsUnit.Pixel);

            using (var whitePen = new Pen(Color.White, 2))
            {
                whitePen.Alignment = PenAlignment.Inset;
                g.DrawRectangle(whitePen, 0, 0, tw, th);
            }

            using (var blackPen = new Pen(Color.Black, 1))
            {
                g.DrawRectangle(blackPen, 0, 0, tw, th);
                g.DrawRectangle(blackPen, 2, 2, tw - 4, th - 4);
            }

            base.OnPaint(e);

        }

        public void Render(Graphics g)
        {
            var rect = new Rectangle(0, 0, ClientSize.Width, ClientSize.Height);
            var tw = rect.Width;
            var th = rect.Height;
            var px = Location.X;
            var py = Location.Y;

            g.DrawImage(TilesetImage, 0, 0, srcRect, GraphicsUnit.Pixel);

            using (var whitePen = new Pen(Color.White, 2))
            {
                whitePen.Alignment = PenAlignment.Inset;
                g.DrawRectangle(whitePen, px, py, tw, th);
            }

            using (var blackPen = new Pen(Color.Black, 1))
            {
                g.DrawRectangle(blackPen, px, py, tw, th);
                g.DrawRectangle(blackPen, px + 2, py + 2, tw - 4, th - 4);
            }
        }

        ///// <summary>
        ///// 부모 컨트롤에 배경을 그리도록 요청하여 투명도를 시뮬레이션 합니다.
        ///// </summary>
        ///// <param name="e"></param>
        //protected override void OnPaintBackground(PaintEventArgs e)
        //{

        //}
    }
}
