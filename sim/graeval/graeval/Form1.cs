using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.Threading;
using System.IO;
using System.Drawing.Imaging;

namespace graeval
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        string filename = "vga_out.gra";
        Thread exchanger;
        private void Form1_Load(object sender, EventArgs e)
        {
            string[] args = Environment.GetCommandLineArgs();
            if (args.Length > 1)
            {
                filename = args[1];
            }

            while (!File.Exists(filename))
            {
            }

            using (var file = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (var reader = new StreamReader(file))
            {
                string line = reader.ReadLine();
                string[] commandlist = line.Split('#');
                int x = Convert.ToInt32(commandlist[0]);
                int y = Convert.ToInt32(commandlist[1]);

                bmp = new Bitmap(x, y);
                tempbmp = new Bitmap(x, y);
                pictureBox1.Size = new Size(x, y);
                this.Size = new Size(x + 30, y + 50);
            }

            exchanger = new Thread(exchange_process);
            exchanger.Start();
        }



        Bitmap bmp;
        private void Form1_FormClosed(object sender, FormClosedEventArgs e)
        {
            exchanger.Abort();
        }


        private delegate void PaintAsyncDelegate();


        Bitmap tempbmp;
        int x_low = 0;
        int x_high = 0;
        int y_low = 0;
        int y_high = 0;
        private void PaintAsync()
        {
            lock (tempbmp)
            {
                BitmapData data_src = tempbmp.LockBits(new Rectangle(0, 0, tempbmp.Width, tempbmp.Height), ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
                BitmapData data_dst = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
                int stride_src = data_src.Stride;
                int stride_dst = data_dst.Stride;
                unsafe
                {
                    byte* ptr_src = (byte*)data_src.Scan0;
                    byte* ptr_dst = (byte*)data_dst.Scan0;
                    for (int x = x_low; x <= x_high; x++)
                    {
                        for (int y = y_low; y <= y_high; y++)
                        {
                            ptr_dst[(x * 3) + y * stride_dst + 0] = ptr_src[(x * 3) + y * stride_src + 0];
                            ptr_dst[(x * 3) + y * stride_dst + 1] = ptr_src[(x * 3) + y * stride_src + 1];
                            ptr_dst[(x * 3) + y * stride_dst + 2] = ptr_src[(x * 3) + y * stride_src + 2];
                        }
                    }
                }
                tempbmp.UnlockBits(data_src);
                bmp.UnlockBits(data_dst);
            }
        }

        private void exchange_process()
        {
            using (var file = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (var reader = new StreamReader(file))
            {
                string line = reader.ReadLine();

                int changed = 0;
                while (true)
                {
                    DateTime start = DateTime.Now;
                    lock (tempbmp)
                    {
                        BitmapData data = tempbmp.LockBits(new Rectangle(0, 0, tempbmp.Width, tempbmp.Height), ImageLockMode.ReadWrite, PixelFormat.Format24bppRgb);
                        int stride = data.Stride;
                        unsafe
                        {
                            byte* ptr = (byte*)data.Scan0;
                            while (!reader.EndOfStream && reader.BaseStream.Position < reader.BaseStream.Length - 100 && (DateTime.Now - start).TotalMilliseconds < 250)
                            {
                                line = reader.ReadLine();

                                string[] commandlist = line.Split('#');

                                int x = Convert.ToInt32(commandlist[1]);
                                int y = Convert.ToInt32(commandlist[2]);
                                if (x >= 0 && x < tempbmp.Width && y >= 0 && y < tempbmp.Height)
                                {
                                    x_low = Math.Min(x_low, x);
                                    x_high = Math.Max(x_high, x);
                                    y_low = Math.Min(y_low, y);
                                    y_high = Math.Max(y_high, y);

                                    int c = Convert.ToInt32(commandlist[0]);
                                    int cr = (c >> 16) & 255;
                                    int cg = (c >> 8) & 255;
                                    int cb = c & 255;

                                    ptr[(x * 3) + y * stride + 0] = (byte)cb;
                                    ptr[(x * 3) + y * stride + 1] = (byte)cg;
                                    ptr[(x * 3) + y * stride + 2] = (byte)cr;

                                    changed++;
                                }
                            }
                        }
                        tempbmp.UnlockBits(data);
                    }

                    if (changed > 0)
                    {
                        pictureBox1.Invoke(new PaintAsyncDelegate(PaintAsync));
                        changed = 0;
                        x_low = 0xFFFF;
                        x_high = 0;
                        y_low = 0xFFFF;
                        y_high = 0;
                    }
                }
            }
        }

        private void timer1_Tick(object sender, EventArgs e)
        {
            pictureBox1.Image = bmp;
        }






    }
}
