class Dmd < Formula
  desc "D programming language compiler for macOS"
  homepage "https://dlang.org/"

  stable do
    url "https://github.com/dlang/dmd/archive/v2.073.2.tar.gz"
    sha256 "1cd983d73b0fa1a20232fb46dbc3a39434adfa00fc7668563983ec8ca210726a"

    resource "druntime" do
      url "https://github.com/dlang/druntime/archive/v2.073.2.tar.gz"
      sha256 "9c0c1a818deb6a0d410f83f067450cc5b41287328c44c2d46c0d2e7de84aa68e"
    end

    resource "phobos" do
      url "https://github.com/dlang/phobos/archive/v2.073.2.tar.gz"
      sha256 "6a3b16649a33bcc3db522404a1fe98f046eedf082a96648f7972ab112c2cb289"
    end

    resource "tools" do
      url "https://github.com/dlang/tools/archive/v2.073.2.tar.gz"
      sha256 "6e702dcbf73d4673a8a9320a01170ad1ae59945a3646d343b14c4cac88b735e6"
    end
  end

  bottle do
    sha256 "15d0e7df1e0ca6394deebfcb241de401c58d255cc29985b72e3a30a6be160441" => :sierra
    sha256 "6d5c55b67bdb8091aa46095be773c154caf967c0f0b64927e9f2d02e7117843a" => :el_capitan
    sha256 "5c2eeb78936b42e91edc2cb9038f6772b16af0ca2a3d24b4788261417077fcd3" => :yosemite
  end

  devel do
    url "https://github.com/dlang/dmd/archive/v2.074.0-b2.tar.gz"
    sha256 "196474a000cb82c2bea695126fba88de7d5ae50f6fecf61425a0e4cb379e2bca"
    version "2.074.0-b2"

    resource "druntime" do
      url "https://github.com/dlang/druntime/archive/v2.074.0-b2.tar.gz"
      sha256 "3dc339705a5eea80397ac506d8b971e822e2a908590bf133790458c057eac981"
      version "2.074.0-b2"
    end

    resource "phobos" do
      url "https://github.com/dlang/phobos/archive/v2.074.0-b2.tar.gz"
      sha256 "ad9ddd925ac8c6941f1ad97b8c42a680e5454dc8b6e4c9ec606e4bd3283508a9"
      version "2.074.0-b2"
    end

    resource "tools" do
      url "https://github.com/dlang/tools/archive/v2.074.0-b2.tar.gz"
      sha256 "63c575b942c47750289ee9ed82c2bbb8b7dfddbf5d6789f0243498761dcf91dd"
      version "2.074.0-b2"
    end
  end

  head do
    url "https://github.com/dlang/dmd.git"

    resource "druntime" do
      url "https://github.com/dlang/druntime.git"
    end

    resource "phobos" do
      url "https://github.com/dlang/phobos.git"
    end

    resource "tools" do
      url "https://github.com/dlang/tools.git"
    end
  end

  def install
    make_args = ["INSTALL_DIR=#{prefix}", "MODEL=#{Hardware::CPU.bits}", "-f", "posix.mak"]

    system "make", "SYSCONFDIR=#{etc}", "TARGET_CPU=X86", "AUTO_BOOTSTRAP=1", "RELEASE=1", *make_args

    bin.install "src/dmd"
    prefix.install "samples"
    man.install Dir["docs/man/*"]

    # A proper dmd.conf is required for later build steps:
    conf = buildpath/"dmd.conf"
    # Can't use opt_include or opt_lib here because dmd won't have been
    # linked into opt by the time this build runs:
    conf.write <<-EOS.undent
        [Environment]
        DFLAGS=-I#{include}/dlang/dmd -L-L#{lib}
        EOS
    etc.install conf
    install_new_dmd_conf

    make_args.unshift "DMD=#{bin}/dmd"

    (buildpath/"druntime").install resource("druntime")
    (buildpath/"phobos").install resource("phobos")

    system "make", "-C", "druntime", *make_args
    system "make", "-C", "phobos", "VERSION=#{buildpath}/VERSION", *make_args

    (include/"dlang/dmd").install Dir["druntime/import/*"]
    cp_r ["phobos/std", "phobos/etc"], include/"dlang/dmd"
    lib.install Dir["druntime/lib/*", "phobos/**/libphobos2.a"]

    resource("tools").stage do
      inreplace "posix.mak", "install: $(TOOLS) $(CURL_TOOLS)", "install: $(TOOLS) $(ROOT)/dustmite"
      system "make", "install", *make_args
    end
  end

  # Previous versions of this formula may have left in place an incorrect
  # dmd.conf.  If it differs from the newly generated one, move it out of place
  # and warn the user.
  # This must be idempotent because it may run from both install() and
  # post_install() if the user is running `brew install --build-from-source`.
  def install_new_dmd_conf
    conf = etc/"dmd.conf"

    # If the new file differs from conf, etc.install drops it here:
    new_conf = etc/"dmd.conf.default"
    # Else, we're already using the latest version:
    return unless new_conf.exist?

    backup = etc/"dmd.conf.old"
    opoo "An old dmd.conf was found and will be moved to #{backup}."
    mv conf, backup
    mv new_conf, conf
  end

  def post_install
    install_new_dmd_conf
  end

  test do
    system bin/"dmd", prefix/"samples/hello.d"
    system "./hello"
  end
end
