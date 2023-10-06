# Formula for Python nwdiag and rackdiag (from the blockdiag project)
#
# https://pypi.org/project/nwdiag/
# https://github.com/blockdiag/nwdiag
#
# pillow 10.0 removes the font "getsize"
#
# https://github.com/tensorflow/models/issues/11040
# https://github.com/ultralytics/yolov5/issues/11838
# https://pillow.readthedocs.io/en/stable/releasenotes/10.0.0.html#font-size-and-offset-methods
#
# and blockdiag upstream has not been updated since 2021. So we have to inject
# a patch for the source to use getbbox() instead of getsize(); the
# relevant calls appear to be in blockdiag png.py, although it is unclear
# exactly how they are reached.
#
# Written by Ewen McNeill <ewen@naos.co.nz>, 2022-08-22
# Updated by Ewen McNeill <ewen@naos.co.nz>, 2023-10-06
#
#---------------------------------------------------------------------------
# SPDX-License-Identifier: MIT
# 
# Copyright 2022 Naos Limited
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# “Software”), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject
# to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
# ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#---------------------------------------------------------------------------

class Nwdiag < Formula
  include Language::Python::Virtualenv

  desc "Network Diagram tools from BlockDiag"
  homepage "http://blockdiag.com/"
  url "https://files.pythonhosted.org/packages/5a/75/06920ff030f924638b045be3d1dbaf92b8fc462d154515ef5b6c57d7d561/nwdiag-3.0.0.tar.gz"
  sha256 "e267530fcaac8a1d9e7403048597ed30e031e17f0191569dc6f704087bacb2eb"
  license "Apache-2.0"

  depends_on "pillow"
  depends_on "python@3.10"
  depends_on "librsvg"

  resource "blockdiag" do
    url "https://files.pythonhosted.org/packages/b4/eb/e2a4b6d5bf7f7121104ac7a1fc80b5dfa86ba286adbd1f25bf32a090a5eb/blockdiag-3.0.0.tar.gz"
    sha256 "dee4195bb87d23654546ba2bf5091480dbf253b409891fce2cd527c91d00a3e2"

    # 2023-09-28 blockdiag 3.0.0 needs work around for Pillow 10 removing font.getsize()
    patch :DATA
  end

  resource "funcparserlib" do
    url "https://files.pythonhosted.org/packages/53/6b/02fcfd2e46261684dcd696acec85ef6c244b73cd31c2a5f2008fbfb434e7/funcparserlib-1.0.0.tar.gz"
    sha256 "7dd33dd4299fc55cbdbf4b9fdfb3abc54d3b5ed0c694b83fb38e9e3e8ac38b6b"
  end

  resource "webcolors" do
    url "https://files.pythonhosted.org/packages/5f/f5/004dabd8f86abe0e770df4bcde8baf658709d3ebdd4d8fa835f6680012bb/webcolors-1.12.tar.gz"
    sha256 "16d043d3a08fd6a1b1b7e3e9e62640d09790dce80d2bdd4792a175b35fe794a9"
  end

  def install
    # Base package and dependency install, auto-symlinks nwdiag
    # virtualenv_install_with_resources
    # 
    # Separated, as we need to patch the blockdiag resource
    venv = virtualenv_create(libexec)
    venv.pip_install resources
    venv.pip_install_and_link buildpath
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # TODO: Figure out how to run tests
    #
    system "true"
  end
end

__END__
diff --git a/src/blockdiag/imagedraw/png.py b/src/blockdiag/imagedraw/png.py
index 3cac05a..f65fd3a 100644
--- a/src/blockdiag/imagedraw/png.py
+++ b/src/blockdiag/imagedraw/png.py
@@ -269,6 +269,19 @@ class ImageDrawExBase(base.ImageDraw):
         textfolder = super(ImageDrawExBase, self).textfolder
         return partial(textfolder, scale=self.scale_ratio)
 
+    # 2023-09-28 -- work around for Pillow 10 which removes font.getsize()
+    # https://pillow.readthedocs.io/en/stable/releasenotes/10.0.0.html#font-size-and-offset-methods
+    # https://pillow.readthedocs.io/en/stable/reference/ImageFont.html#PIL.ImageFont.FreeTypeFont.getbbox
+    #
+    def _ttfont_getsize(self, ttfont, display_str):
+        if hasattr(ttfont, 'getsize'):
+            return ttfont.getsize(display_str)
+        else:
+            l, t, r, b  = ttfont.getbbox(display_str)
+            text_width  = (r-l)
+            text_height = (b-t)
+            return text_width, text_height
+
     @memoize
     def textlinesize(self, string, font):
         ttfont = ttfont_for(font)
@@ -279,7 +292,9 @@ class ImageDrawExBase(base.ImageDraw):
             size = Size(int(size[0] * font_ratio),
                         int(size[1] * font_ratio))
         else:
-            size = Size(*ttfont.getsize(string))
+            # 2023-09-28 -- wrok around for Pillow 10 which removes font.getsize
+            # size = Size(*ttfont.getsize(string))
+            size = Size(*self._ttfont_getsize(ttfont, string))
 
         return size
 
@@ -302,7 +317,9 @@ class ImageDrawExBase(base.ImageDraw):
                 text_image = image.resize(basesize, Image.ANTIALIAS)
                 self.paste(text_image, xy, text_image)
         else:
-            size = ttfont.getsize(string)
+            # 2023-09-28 -- work around for Pillow 10 which removes font.getsize
+            # size = ttfont.getsize(string)
+            size = self._ttfont_getsize(ttfont, string)
 
             # Generate mask to support BDF(bitmap font)
             mask = Image.new('1', size)
