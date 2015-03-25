defmodule AwsTest do
  use ExUnit.Case
  
  import Aws.Http

  alias Aws.Auth.Signature
  
  test "Render URI template." do
    template = "/{Bucket}/{Key+}"
    assert "/bucket/key" =
      render_uri_template(template, [Bucket: "bucket",
                                     Key: "key"])
    
    assert "/bucket%2Fbucket/key1/key2" =
      render_uri_template(template, [Bucket: "bucket/bucket",
                                     Key: "key1/key2"])
  end

  test "Service endpoint config." do
    endpoint = Aws.Endpoints.get("us-east-1", :ec2)
    assert endpoint.uri == "https://ec2.us-east-1.amazonaws.com"
    
    endpoint = Aws.Endpoints.get("cn-north-1", :iam)
    assert endpoint.uri == "https://iam.cn-north-1.amazonaws.com.cn"
  end

  test "Auth signature" do
    request = %Aws.Http.Request
    {
        :method => "POST",
        :uri => %URI{:path => "/"},
        :headers => [{"Host", "iam.amazonaws.com"},
                     {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"}],
        :payload => "Action=ListUsers&Version=2010-05-08"
    }

    {_headers, string} = Signature.V4.canonical_request(request)
    
    string_to_sign = Signature.V4.string_to_sign(
      "us-east-1", "s3", "20110909T233600Z", "20110909", string)
    
    assert string_to_sign == "AWS4-HMAC-SHA256\n20110909T233600Z\n20110909/us-east-1/s3/aws4_request\n2098121695415a5bdb2d3c23f440af5925044137cf69807312b7825bf172e960"

    home = System.get_env("HOME")

    # mock home dir to test
    System.put_env("HOME", Path.join(System.cwd!, "test"))
    
    {:ok, request} = Signature.V4.sign(request, "us-east-1", "s3")

    # bring back home
    System.put_env("HOME", home)
  end

  test "Canonical header string" do
    headers = [{"host", "iam.amazonaws.com"},
               {"Content-type", "application/x-www-form-urlencoded; charset=utf8"},
               {"My-header1", "      a    b   c"},
               {"x-amz-date", "20120228T030031Z"},
               {"My-Header2", "a    b    c"}]

    {signed_headers, canonical_string} = Signature.V4.canonical_headers(headers)

    assert signed_headers == "content-type;host;my-header1;my-header2;x-amz-date"
    
    assert canonical_string == "content-type:application/x-www-form-urlencoded; charset=utf8\n" <>
      "host:iam.amazonaws.com\nmy-header1:a    b   c\nmy-header2:a    b    c\n" <>
      "x-amz-date:20120228T030031Z\n"
  end

  test "Canonical reguest" do
    request = %Aws.Http.Request
    {
        :method => "POST",
        :uri => %URI{:path => "/"},
        :headers => [{"Host", "iam.amazonaws.com"},
                     {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"},
                     {"X-Amz-Date", "20110909T233600Z"}],
        :payload => "Action=ListUsers&Version=2010-05-08"
    }
    
    {_headers, string} = Signature.V4.canonical_request(request)
    hash = Aws.Auth.Utils.sha256(string)
    |> Aws.Auth.Utils.hexdigest
    
    assert hash == "3511de7e95d28ecd39e9513b642aee07e54f4941150d8df8bf94b328ef7e55e2"
  end

  test "Load configs from env" do
    System.put_env("AWS_ACCESS_KEY_ID", "KEY_FROM_ENV")
    System.put_env("AWS_SECRET_ACCESS_KEY", "SECRET_FROM_ENV")
    System.put_env("AWS_DEFAULT_REGION", "REGION_FROM_ENV")

    configs = Aws.Config.get()

    assert configs != %Aws.Config.Configs{}
    assert configs.key == "KEY_FROM_ENV"
    assert configs.secret == "SECRET_FROM_ENV"
    assert configs.region == "REGION_FROM_ENV"

    System.delete_env("AWS_ACCESS_KEY_ID")
    System.delete_env("AWS_SECRET_ACCESS_KEY")
    System.delete_env("AWS_DEFAULT_REGION")
  end
  
  test "Load AWS CLI configs" do
    home = System.get_env("HOME")

    # mock home dir to test
    System.put_env("HOME", Path.join(System.cwd!, "test"))

    configs = Aws.Config.get()

    assert configs != %Aws.Config.Configs{}
    assert configs.key == "AWS_ACCESS_KEY_ID"
    assert configs.secret == "AWS_SECRET_ACCESS_KEY"
    assert configs.region == "us-east-1"

    # bring back home
    System.put_env("HOME", home)
  end

  test "Signature example" do
    System.put_env("AWS_ACCESS_KEY_ID", "AKIAIOSFODNN7EXAMPLE")
    System.put_env("AWS_SECRET_ACCESS_KEY", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")

    request = %Aws.Http.Request
    {
        :method => "GET",
        :uri => %URI
        {
            :path => "/test.txt",
            :host => "examplebucket.s3.amazonaws.com"
        },
        :headers => [{"Range", "bytes=0-9"},
                     {"Host", "examplebucket.s3.amazonaws.com"},
                     {"x-amz-content-sha256",
                      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"},
                     {"x-amz-date", "20130524T000000Z"}]
    }

    signed_request = Signature.V4.sign(request, "us-east-1", "s3")
    
    System.delete_env("AWS_ACCESS_KEY_ID")
    System.delete_env("AWS_SECRET_ACCESS_KEY")
  end
  
end
