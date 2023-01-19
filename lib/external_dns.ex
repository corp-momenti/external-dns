defmodule ExternalDns do
  require Logger

  def start() do
    multi_cluster_ingresses()
    |> Enum.filter(&is_valid/1)
    |> Enum.each(&upsert_dns/1)
  end

  def multi_cluster_ingresses() do
    multi_cluster_ingresses(nil)
  end

  def multi_cluster_ingresses("") do
    []
  end

  def multi_cluster_ingresses(continue) do
    {:ok, token} = File.read("/var/run/secrets/kubernetes.io/serviceaccount/token")

    {:ok, cacert} = File.read("/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")

    [{:Certificate, der, :not_encrypted}] = :public_key.pem_decode(cacert)

    {:ok, {{'HTTP/1.1', 200, _status}, _headers, body}} =
      :httpc.request(
        :get,
        {"https://kubernetes.default.svc/apis/networking.gke.io/v1/multiclusteringresses?#{URI.encode_query(%{"continue" => continue})}",
         [{'Accept', 'application/json'}, {'Authorization', 'Bearer #{token}'}]},
        [
          {:ssl,
           [
             {:cacerts, [der]},
             {:customize_hostname_check,
              [{:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}]},
             {:depth, 3},
             {:verify, :verify_peer}
           ]}
        ],
        [{:body_format, :binary}]
      )

    {:ok, %{"items" => items, "metadata" => %{"continue" => continue}}} = Jason.decode(body)

    items ++ multi_cluster_ingresses(continue)
  end

  def is_valid(%{
        "apiVersion" => "networking.gke.io/v1",
        "kind" => "MultiClusterIngress",
        "metadata" => %{
          "annotations" => %{
            "external-dns/managed-zone" => <<_, _::binary>>,
            "external-dns/hostname" => <<_, _::binary>>
          }
        },
        "status" => %{"VIP" => <<_, _::binary>>}
      }) do
    true
  end

  def is_valid(_) do
    false
  end

  def upsert_dns(%{
        "metadata" => %{
          "annotations" => %{
            "external-dns/managed-zone" => managed_zone,
            "external-dns/hostname" => hostname
          }
        },
        "status" => %{"VIP" => vip}
      }) do
    {:ok, {{'HTTP/1.1', 200, _status}, _headers, project_id}} =
      :httpc.request(
        :get,
        {
          "http://metadata.google.internal/computeMetadata/v1/project/project-id",
          [{'Accept', 'application/text'}, {'Metadata-Flavor', 'Google'}]
        },
        [],
        [{:body_format, :binary}]
      )

    {:ok, {{'HTTP/1.1', 200, _status}, _headers, body}} =
      :httpc.request(
        :get,
        {
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token",
          [{'Accept', 'application/json'}, {'Metadata-Flavor', 'Google'}]
        },
        [],
        [{:body_format, :binary}]
      )

    {:ok, %{"access_token" => token}} = Jason.decode(body)

    {:ok, resource_record_set} =
      %{
        "kind" => "dns#resourceRecordSet",
        "name" => "#{hostname}.",
        "rrdatas" => [vip],
        "ttl" => 300,
        "type" => "A"
      }
      |> Jason.encode()

    {:ok, {{'HTTP/1.1', 200, _status}, _headers, _body}} =
      :httpc.request(
        :get,
        {
          "https://dns.googleapis.com/dns/v1/projects/#{project_id}/managedZones/#{managed_zone}/rrsets/#{hostname}./A",
          [{'Accept', 'application/json'}, {'Authorization', 'Bearer #{token}'}]
        },
        [
          {:ssl,
           [
             {:cacerts, :certifi.cacerts()},
             {:customize_hostname_check,
              [{:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}]},
             {:depth, 3},
             {:verify, :verify_peer}
           ]}
        ],
        [{:body_format, :binary}]
      )
      |> case do
        {:ok, {{'HTTP/1.1', 200, _status}, _headers, _body}} ->
          :httpc.request(
            :patch,
            {
              "https://dns.googleapis.com/dns/v1/projects/#{project_id}/managedZones/#{managed_zone}/rrsets/#{hostname}./A",
              [
                {'Accept', 'application/json'},
                {'Authorization', 'Bearer #{token}'}
              ],
              'application/json',
              resource_record_set
            },
            [
              {:ssl,
               [
                 {:cacerts, :certifi.cacerts()},
                 {:customize_hostname_check,
                  [{:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}]},
                 {:depth, 3},
                 {:verify, :verify_peer}
               ]}
            ],
            [{:body_format, :binary}]
          )

        {:ok, {{'HTTP/1.1', 404, _status}, _headers, _body}} ->
          :httpc.request(
            :post,
            {
              "https://dns.googleapis.com/dns/v1/projects/#{project_id}/managedZones/#{managed_zone}/rrsets",
              [
                {'Accept', 'application/json'},
                {'Authorization', 'Bearer #{token}'}
              ],
              'application/json',
              resource_record_set
            },
            [
              {:ssl,
               [
                 {:cacerts, :certifi.cacerts()},
                 {:customize_hostname_check,
                  [{:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}]},
                 {:depth, 3},
                 {:verify, :verify_peer}
               ]}
            ],
            [{:body_format, :binary}]
          )
      end

    Logger.info("upserted: #{resource_record_set}")
  end
end
