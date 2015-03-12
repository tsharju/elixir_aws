defmodule AwsTest do
  use ExUnit.Case
  
  import Aws.Http
  
  test "Render URI template." do
    template = "/{Bucket}/{Key+}"
    assert "/bucket/key" =
      render_uri_template(template, [bucket: "bucket",
                                     key: "key"])
    
    assert "/bucket%2Fbucket/key1/key2" =
      render_uri_template(template, [bucket: "bucket/bucket",
                                     key: "key1/key2"])
  end

  test "Service endpoint config." do
    endpoint = Aws.Endpoints.get("us-east-1", :ec2)
    assert endpoint["uri"] == "{scheme}://{service}.{region}.amazonaws.com"
    
    endpoint = Aws.Endpoints.get("cn-north-1", :iam)
    assert endpoint["uri"] == "https://{service}.cn-north-1.amazonaws.com.cn"
  end
  
end
