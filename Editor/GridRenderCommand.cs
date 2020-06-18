using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Drawing;
using DarkUI.Config;

namespace Editor
{
    /// <summary>
    /// GridRenderCommand
    /// </summary>
    class GridRenderCommand : IRenderCommand
    {
        public void Execute(Graphics g, object[] args)
        {
            Pen p = new Pen(Colors.BlueHighlight);

            var db = DataManager.Instance;
            List<Point> list = new List<Point>();

            var maxGridX = db.MapWidth * db.TileWidth;
            var maxGridY = db.MapHeight * db.TileHeight;

            var mx = (int)args[0];
            var my = (int)args[1];
            var tw = db.TileWidth;
            var th = db.TileHeight;

            for (int y = 0; y < maxGridY + 1; y += db.TileHeight)
            {
                list.Clear();
                list.Add(new Point(0, y));
                list.Add(new Point(maxGridX, y));
                g.DrawLines(p, list.ToArray());
            }

            for (int x = 0; x < maxGridX + 1; x += db.TileWidth)
            {
                list.Clear();
                list.Add(new Point(x, 0));
                list.Add(new Point(x, maxGridY));
                g.DrawLines(p, list.ToArray());
            }
        }
    }
}
