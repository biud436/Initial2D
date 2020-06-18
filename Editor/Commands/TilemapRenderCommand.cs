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
    class TilemapRenderCommand : IRenderCommand
    {
        private IRenderCommand nextCommand;

        public TilemapRenderCommand(IRenderCommand adapter)
        {
            nextCommand = adapter;
        }

        public void AddLayer()
        {

        }

        public void Execute(Graphics g, object[] args)
        {
            int mapWidth = DataManager.Instance.MapWidth;
            int mapHeight = DataManager.Instance.MapHeight;

            var mx = (int)args[0];
            var my = (int)args[1];
            var tw = DataManager.Instance.TileWidth;
            var th = DataManager.Instance.TileHeight;

            Image tilesetImage = (Image)args[2];

            var mapCols = tilesetImage.Width / tw;
            var mapRows = tilesetImage.Height / th;

            for (int y = 0; y < mapHeight; y++)
            {
                for (int x = 0; x < mapWidth; x++)
                {
                    var tileId = DataManager.Instance.Layer1[y * mapWidth + x];
                    var col = tileId % mapCols;
                    var row = Math.Abs(tileId / mapCols);
                    var nx = col * tw;
                    var ny = row * th;

                    Rectangle srcRect = new Rectangle(nx, ny, tw, th);
                    g.DrawImage(tilesetImage, x * tw, y * th, srcRect, GraphicsUnit.Pixel);

                }
            }

            nextCommand.Execute(g, new object[] { mx, my });
        }
    }
}
