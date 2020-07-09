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
    abstract class IRenderCommand
    {
        public abstract void Execute(Graphics g, object[] args);
    }

    interface IControlCommand
    {
        void Execute(Control control, object[] args);
    }

}
