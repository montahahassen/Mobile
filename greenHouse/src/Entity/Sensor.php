<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use App\Repository\SensorRepository;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\Common\Collections\Collection;
use Doctrine\ORM\Mapping as ORM;

#[ORM\Entity(repositoryClass: SensorRepository::class)]
#[ORM\Table(name: 'sensors')]
#[ORM\UniqueConstraint(name: 'UNIQ_SENSOR_DEVICE_TYPE', columns: ['device_id', 'type'])]
#[ApiResource]
class Sensor
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null;

    #[ORM\Column(length: 30)]
    private ?string $type = null;

    #[ORM\Column(length: 10)]
    private ?string $unit = null;

    #[ORM\Column(length: 100, nullable: true)]
    private ?string $label = null;

    #[ORM\ManyToOne(inversedBy: 'sensors')]
    #[ORM\JoinColumn(nullable: false, onDelete: 'CASCADE')]
    private ?Device $device = null;

    /**
     * @var Collection<int, Measurement>
     */
    #[ORM\OneToMany(targetEntity: Measurement::class, mappedBy: 'sensor', orphanRemoval: true)]
    private Collection $measurements;

    public function __construct()
    {
        $this->measurements = new ArrayCollection();
    }

    public function getId(): ?int
    {
        return $this->id;
    }

    public function getType(): ?string
    {
        return $this->type;
    }

    public function setType(string $type): static
    {
        $this->type = $type;
        return $this;
    }

    public function getUnit(): ?string
    {
        return $this->unit;
    }

    public function setUnit(string $unit): static
    {
        $this->unit = $unit;
        return $this;
    }

    public function getLabel(): ?string
    {
        return $this->label;
    }

    public function setLabel(?string $label): static
    {
        $this->label = $label;
        return $this;
    }

    public function getDevice(): ?Device
    {
        return $this->device;
    }

    public function setDevice(?Device $device): static
    {
        $this->device = $device;
        return $this;
    }

    /**
     * @return Collection<int, Measurement>
     */
    public function getMeasurements(): Collection
    {
        return $this->measurements;
    }

    public function addMeasurement(Measurement $measurement): static
    {
        if (!$this->measurements->contains($measurement)) {
            $this->measurements->add($measurement);
            $measurement->setSensor($this);
        }
        return $this;
    }

    public function removeMeasurement(Measurement $measurement): static
    {
        if ($this->measurements->removeElement($measurement)) {
            if ($measurement->getSensor() === $this) {
                $measurement->setSensor(null);
            }
        }
        return $this;
    }
}