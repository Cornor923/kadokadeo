<?php

namespace App\Casts;

use Illuminate\Contracts\Database\Eloquent\CastsAttributes;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\PostgresConnection;
use Illuminate\Support\Facades\DB;

class BinaryCast implements CastsAttributes
{
    protected function getPostgresCast($value)
    {
        if (is_resource($value)) {
            rewind($value);
            $value = stream_get_contents($value);
        }

        return $value;
    }

    protected function setPostgresCast($value)
    {
        if ($value) {
            return bin2hex($value);
        }

        return null;
    }

    /**
     * Cast the given value.
     *
     * @param  array<string, mixed>  $attributes
     */
    public function get(Model $model, string $key, mixed $value, array $attributes): mixed
    {
        if ($model->getConnection() instanceof PostgresConnection) {
            return $this->getPostgresCast($value);
        }

        return $value;
    }

    /**
     * Prepare the given value for storage.
     *
     * @param  array<string, mixed>  $attributes
     */
    public function set(Model $model, string $key, mixed $value, array $attributes): mixed
    {
        if ($model->getConnection() instanceof PostgresConnection) {
            $data = $this->setPostgresCast($value);
            if (is_null($data)) {
                return null;
            }

            return DB::raw("decode('".$data."', 'hex')");
        }

        return $value;
    }
}
