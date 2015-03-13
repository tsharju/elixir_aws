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

  test "Shape expand." do
    spec = File.read!("priv/aws/s3/2006-03-01.normal.json")
    |> Poison.decode!(keys: :atoms)

    shape = Aws.Shape.expand(:'AbortMultipartUploadRequest', spec[:shapes])
    assert shape.type == "structure"
    assert shape.members[:Bucket].shape.type == "string"
    assert shape.members[:Key].shape.type == "string"
    assert shape.members[:UploadId].shape.type == "string"
  end

  test "Auth signature" do
    http_method = "POST"
    uri = "/"
    headers = [{"Host", "iam.amazonaws.com"},
               {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"}]
    payload = "Action=ListUsers&Version=2010-05-08"
    string_to_sign = Signature.V4.string_to_sign("us-east-1", "s3", http_method, uri, headers, payload)
    
    assert string_to_sign != nil # TODO: mock :os.timestamp so we can assert this
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
    http_method = "POST"
    uri = "/"
    headers = [{"Host", "iam.amazonaws.com"},
               {"Content-Type", "application/x-www-form-urlencoded; charset=utf-8"},
               {"X-Amz-Date", "20110909T233600Z"}]
    payload = "Action=ListUsers&Version=2010-05-08"
    
    canonical_request = Signature.V4.canonical_request(http_method, uri, headers, payload)
    hash = Signature.V4.digest(canonical_request)
    
    assert hash == "3511de7e95d28ecd39e9513b642aee07e54f4941150d8df8bf94b328ef7e55e2"
  end
  
end
